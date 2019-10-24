class roundcubemail (
    String $db_host               = 'db4.miraheze.org',
    String $db_name               = 'roundcubemail',
    String $db_user_name          = 'roundcubemail',
    String $db_user_password      = undef,
    String $roundcubemail_des_key = undef,
) {

    include ::nodejs

    $php_version = hiera('php::php_version', '7.2')
    ensure_resource_duplicate('class', 'php::php_fpm', {
        'config'  => {
            'display_errors'            => 'Off',
            'error_log'                 => '/var/log/php/php.log',
            'error_reporting'           => 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
            'log_errors'                => 'On',
            'max_execution_time'        => 100,
            'opcache'                   => {
                'enable'                  => 1,
                'interned_strings_buffer' => 50,
                'memory_consumption'      => 300,
                'max_accelerated_files'   => 24000,
                'max_wasted_percentage'   => 10,
                'validate_timestamps'     => 1,
                'revalidate_freq'         => 10,
            },
            'enable_dl'           => 0,
            'post_max_size'       => '40M',
            'register_argc_argv'  => 'Off',
            'request_order'       => 'GP',
            'track_errors'        => 'Off',
            'upload_max_filesize' => '100M',
            'variables_order'     => 'GPCS',
        },
        'version' => $php_version
    })

    require_package("php${php_version}-pspell")

    git::clone { 'roundcubemail':
        directory          => '/srv/roundcubemail',
        origin             => 'https://github.com/roundcube/roundcubemail',
        branch             => '1.4-rc1', # we are using the beta for the new skin
        recurse_submodules => true,
        owner              => 'www-data',
        group              => 'www-data',
    }

    git::clone { 'roundcubemail_filters':
        ensure             => present,
        directory          => '/srv/roundcubemail/plugins',
        origin             => 'https://github.com/6ec123321/filters',
        branch             => 'filters-2.2.0', # we are using the beta for the new skin
        owner              => 'www-data',
        group              => 'www-data',
        require            => Git::Clone['roundcubemail'],
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
        ensure      => present,
        source      => 'puppet:///modules/roundcubemail/mail.miraheze.org.conf',
        notify_site => Exec['nginx-syntax-roundcubemail'],
    }

    nginx::site { 'roundcubemail':
        ensure      => present,
        source      => 'puppet:///modules/roundcubemail/roundcubemail.conf',
        notify_site => Exec['nginx-syntax-roundcubemail'],
    }

    exec { 'nginx-syntax-roundcubemail':
        command     => '/usr/sbin/nginx -t',
        notify      => Exec['nginx-reload-roundcubemail'],
        refreshonly => true,
    }

    exec { 'nginx-reload-roundcubemail':
        command     => '/usr/sbin/service nginx reload',
        refreshonly => true,
        require     => Exec['nginx-syntax-roundcubemail'],
    }

    monitoring::services { 'webmail.miraheze.org HTTPS':
        check_command  => 'check_http',
        vars           => {
            http_expect => 'HTTP/1.1 401 Unauthorized',
            http_ssl   => true,
            http_vhost => 'webmail.miraheze.org',
        },
     }
}
