# class: matomo
class matomo (
    String $ldap_password = lookup('passwords::matomo::ldap_password'),
) {
    git::clone { 'matomo':
        directory          => '/srv/matomo',
        origin             => 'https://github.com/matomo-org/matomo',
        branch             => '4.4.0', # Current stable
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

    if !defined(Class['php::php_fpm']) {
        class { 'php::php_fpm':
            config  => {
                'display_errors'            => 'Off',
                'error_reporting'           => 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
                'log_errors'                => 'On',
                'memory_limit'              => lookup('php::fpm::memory_limit', {'default_value' => '512M'}),
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
            config_cli => {
                'memory_limit' => lookup('php::cli::memory_limit', {'default_value' => '2G'}),
            },
            fpm_min_child => 4,
            version => lookup('php::php_version', {'default_value' => '7.3'}),
        }
    }

    include ssl::wildcard

    nginx::site { 'matomo.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/matomo/nginx.conf',
        monitor => true,
    }
    
    $salt = lookup('passwords::piwik::salt')
    $password = lookup('passwords::db::piwik')
    $noreply_password = lookup('passwords::mail::noreply')

    file { '/srv/matomo/config/config.ini.php':
        ensure  => present,
        content => template('matomo/config.ini.php.erb'),
        owner   => 'www-data',
        group   => 'www-data',
        require => Git::Clone['matomo'],
    }

    file { '/usr/local/bin/fileLockScript.sh':
        ensure => absent,
        mode   => '0755',
    }

    file { '/usr/local/bin/runMatomoArchive.sh':
        ensure => present,
        mode   => '0755',
        source => 'puppet:///modules/matomo/runMatomoArchive.sh',
    }

    cron { 'archive_matomo':
        ensure  => present,
        command => '/usr/local/bin/runMatomoArchive.sh',
        user    => 'www-data',
        special => 'daily',
    }
}
