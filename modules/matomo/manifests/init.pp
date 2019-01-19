# class: matomo
class matomo {
    git::clone { 'matomo':
        directory          => '/srv/matomo',
        origin             => 'https://github.com/matomo-org/matomo',
        branch             => '3.8.0-rc2', # Current stable
        recurse_submodules => true,
        owner              => 'www-data',
        group              => 'www-data',
    }

    exec { 'curl -sS https://getcomposer.org/installer | php && php composer.phar install':
        creates     => '/srv/matomo/composer.phar',
        cwd         => '/srv/matomo',
        path        => '/usr/bin',
        environment => 'HOME=/srv/matomo',
        user        => 'www-data',
        require     => Git::Clone['matomo'],
    }

    ensure_resource_duplicate('class', 'php::php_fpm', {
        'config'  => {
            'display_errors'              => 'Off',
            'error_log'                   => '/var/log/php/php.log',
            'error_reporting'             => 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
            'log_errors'                  => 'On',
            'max_execution_time'          => 70,
            'opcache'                     => {
                'enable'                  => 1,
                'memory_consumption'      => 256,
                'interned_strings_buffer' => 64,
                'max_accelerated_files'   => 32531,
                'revalidate_freq'         => 60,
            },
            'mysqli'                      => {
                'allow_local_infile'      => 0,
            },
            'post_max_size'               => '35M',
            'register_argc_argv'          => 'Off',
            'request_order'               => 'GP',
            'track_errors'                => 'Off',
            'upload_max_filesize'         => '100M',
            'variables_order'             => 'GPCS',
        },
        'version' => hiera('php::php_version', '7.2'),
    })

    include ssl::wildcard

    nginx::site { 'matomo.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/matomo/nginx.conf',
        monitor => true,
    }
    
    $salt = hiera('passwords::piwik::salt')
    $password = hiera('passwords::db::piwik')
    $noreply_password = hiera('passwords::mail::noreply')

    file { '/srv/matomo/config/config.ini.php':
        ensure  => present,
        content => template('matomo/config.ini.php.erb'),
        owner   => 'www-data',
        group   => 'www-data',
        require => Git::Clone['matomo'],
    }
}
