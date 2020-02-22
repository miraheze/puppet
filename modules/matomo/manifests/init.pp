# class: matomo
class matomo {
    git::clone { 'matomo':
        directory          => '/srv/matomo',
        origin             => 'https://github.com/matomo-org/matomo',
        branch             => '3.13.2', # Current stable
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
            'display_errors'            => 'Off',
            'error_reporting'           => 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
            'log_errors'                => 'On',
            'memory_limit'              => '512M',
            'opcache'                   => {
                'enable'                  => 1,
                'interned_strings_buffer' => 30,
                'memory_consumption'      => 112,
                'max_accelerated_files'   => 20000,
                'max_wasted_percentage'   => 10,
                'validate_timestamps'     => 1,
                'revalidate_freq'         => 10,
            },
            'enable_dl'           => 0,
            'post_max_size'       => '60M',
            'register_argc_argv'  => 'Off',
            'request_order'       => 'GP',
            'track_errors'        => 'Off',
            'upload_max_filesize' => '100M',
            'variables_order'     => 'GPCS',
        },
        'config_cli' => {
            'memory_limit' => '2G',
        },
        'fpm_min_child' => 4,
        'version' => hiera('php::php_version', '7.3'),
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

    file { '/usr/local/bin/fileLockScript.sh':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/matomo/fileLockScript.sh',
    }

    cron { 'archive_matomo':
        ensure  => present,
        command => '/usr/local/bin/fileLockScript.sh /tmp/matomo_file_lock "/usr/bin/nice -19 /usr/bin/php /srv/matomo/console core:archive --url=https://matomo.miraheze.org/ --concurrent-requests-per-website=1" > /srv/matomo-archive.log',
        user    => 'www-data',
        minute  => '30',
        hour    => '*/24',
    }
}
