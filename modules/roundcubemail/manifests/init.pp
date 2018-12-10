class roundcubemail (
    String $db_host               = 'db4.miraheze.org',
    String $db_name               = 'roundcubemail',
    String $db_user_name          = 'roundcubemail',
    String $db_user_password      = undef,
    String $roundcubemail_des_key = undef,
) {

    include ::nodejs
    include ::php

    require_package('php7.2-pspell')

    git::clone { 'roundcubemail':
        directory          => '/srv/roundcubemail',
        origin             => 'https://github.com/roundcube/roundcubemail',
        branch             => '1.4-beta', # we are using the beta for the new skin
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
