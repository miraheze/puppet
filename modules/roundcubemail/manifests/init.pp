class roundcubemail (
    String $db_host               = 'db13.miraheze.org',
    String $db_name               = 'roundcubemail',
    String $db_user_name          = 'roundcubemail',
    String $db_user_password      = undef,
    String $roundcubemail_des_key = undef,
) {
    include nodejs

    $php_version = lookup('php::php_version', {'default_value' => '7.3'})
    if !defined(Class['php::php_fpm']) {
        class { 'php::php_fpm':
            config  => {
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
            config_cli => {
                'memory_limit' => lookup('php::cli::memory_limit', {'default_value' => '400M'}),
            },
            fpm_min_child => 4,
            version => $php_version
        }
    }

    ensure_packages("php${php_version}-pspell")

    git::clone { 'roundcubemail':
        directory          => '/srv/roundcubemail',
        origin             => 'https://github.com/roundcube/roundcubemail',
        branch             => '1.5.1', # we are using the beta for the new skin
        recurse_submodules => true,
        owner              => 'www-data',
        group              => 'www-data',
    }

    file { '/srv/roundcubemail/config/config.inc.php':
        ensure => present,
        content => template('roundcubemail/config.inc.php.erb'),
        owner  => 'www-data',
        group  => 'www-data',
        require => Git::Clone['roundcubemail'],
    }

    include ssl::wildcard

    nginx::site { 'mail':
        ensure => present,
        source => 'puppet:///modules/roundcubemail/mail.miraheze.org.conf',
    }

    nginx::site { 'roundcubemail':
        ensure => present,
        source => 'puppet:///modules/roundcubemail/roundcubemail.conf',
    }

    file { '/var/log/roundcubemail':
        ensure  => directory,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0640',
        require => Package['nginx'],
    }

    logrotate::conf { 'roundcubemail':
        ensure  => present,
        source  => 'puppet:///modules/roundcubemail/roundcubemail.logrotate.conf',
        require => File['/var/log/roundcubemail'],
    }

    monitoring::services { 'webmail.miraheze.org HTTPS':
        check_command  => 'check_http',
        vars           => {
            http_ssl   => true,
            http_vhost => 'webmail.miraheze.org',
        },
     }
}
