class icingaweb2 (
    String $db_host              = 'db4.miraheze.org',
    String $db_name              = 'icingaweb2',
    String $db_user_name         = 'icingaweb2',
    String $db_user_password     = undef,
    String $ido_db_host          = 'db4.miraheze.org',
    String $ido_db_name          = 'icinga',
    String $ido_db_user_name     = 'icinga2',
    String $ido_db_user_password = undef,
    String $icinga_api_password  = undef,
) {

    if ! defined(Class['::icinga2']) {
        fail('You must include the icinga2 base class before using any icingaweb2 feature class!')
    }

    include ::php

    package { [ 'icingaweb2', 'icingaweb2-module-monitoring',
                'icingaweb2-module-doc', 'icingacli' ]:
        ensure  => present,
        require => Apt::Source['icinga-stable-release'],
    }

    file { '/etc/icingaweb2':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'icingaweb2',
        mode    => '2755',
        require => Package['icingaweb2'],
    }

    file { '/etc/icingaweb2/authentication.ini':
        ensure => present,
        content => template('icingaweb2/authentication.ini.erb'),
        owner  => 'www-data',
        group  => 'icingaweb2',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/groups.ini':
        ensure  => present,
        content => template('icingaweb2/groups.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/resources.ini':
        ensure  => present,
        content => template('icingaweb2/resources.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/roles.ini':
        ensure => present,
        content => template('icingaweb2/roles.ini.erb'),
        owner  => 'www-data',
        group  => 'icingaweb2',
    }

    file { '/etc/icingaweb2/enabledModules':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'icingaweb2',
        mode    => '2755',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/enabledModules/doc':
        ensure  => 'link',
        target  => '/usr/share/icingaweb2/modules/doc',
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/enabledModules'],
    }

    file { '/etc/icingaweb2/enabledModules/monitoring':
        ensure  => 'link',
        target  => '/usr/share/icingaweb2/modules/monitoring',
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/enabledModules'],
    }

    file { '/etc/icingaweb2/enabledModules/setup':
        ensure  => 'link',
        target  => '/usr/share/icingaweb2/modules/setup',
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/enabledModules'],
    }

    file { '/etc/icingaweb2/enabledModules/translation':
        ensure  => 'link',
        target  => '/usr/share/icingaweb2/modules/translation',
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/enabledModules'],
    }

    file { '/etc/icingaweb2/modules':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'icingaweb2',
        mode    => '2755',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/modules/monitoring':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'icingaweb2',
        mode    => '2755',
        require => File['/etc/icingaweb2/modules'],
    }
    
    file { '/etc/icingaweb2/modules/monitoring/backends.ini':
        ensure  => present,
        content  => template('icingaweb2/backends.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/modules/monitoring'],
    }

    file { '/etc/icingaweb2/modules/monitoring/commandtransports.ini':
        ensure  => present,
        content => template('icingaweb2/commandtransports.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/modules/monitoring'],
    }

    include ssl::wildcard

    nginx::site { 'icinga2':
        ensure      => present,
        source      => 'puppet:///modules/icingaweb2/icinga2.conf',
        notify_site => Exec['nginx-syntax-icinga'],
    }

    file_line { 'set_date_time':
        line    => 'date.timezone = Etc/Utc',
        match   => '^;?date.timezone\s*\=',
        path    => '/etc/php/7.2/fpm/php.ini',
        notify  => Exec['nginx-syntax-icinga'],
    }

    exec { 'nginx-syntax-icinga':
        command     => '/usr/sbin/nginx -t',
        notify      => Exec['nginx-reload-icinga'],
        refreshonly => true,
    }

    exec { 'nginx-reload-icinga':
        command     => '/usr/sbin/service nginx reload',
        refreshonly => true,
        require     => Exec['nginx-syntax-icinga'],
    }

    monitoring::services { 'icinga.miraheze.org HTTPS':
        check_command  => 'check_http',
        vars           => {
            http_ssl   => true,
            http_vhost => 'icinga.miraheze.org',
        },
     }
}
