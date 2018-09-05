class icinga2::web(
    $icingaweb_db_host = hiera('icingaweb_db_host', 'db4.miraheze.org'),
    $icingaweb_db_name = hiera('icingaweb_db_name', 'icingaweb2'),
    $icingaweb_user_name = hiera('icingaweb_user_name', 'icingaweb2'),
    $icingaweb_password = hiera('passwords::icingaweb2'),
    $icinga_ido_db_host = hiera('icinga_ido_db_host', 'db4.miraheze.org'),
    $icinga_ido_db_name = hiera('icinga_ido_db_name', 'icinga'),
    $icinga_ido_user_name = hiera('icinga_ido_user_name', 'icinga2'),
    $icinga_ido_password = hiera('passwords::icinga_ido'),
    $icinga_api_password = hiera('passwords::icinga_api'),
) {
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
        content => template('icinga2/web/authentication.ini.erb'),
        owner  => 'www-data',
        group  => 'icingaweb2',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/groups.ini':
        ensure  => present,
        content => template('icinga2/web/groups.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/resources.ini':
        ensure  => present,
        content => template('icinga2/web/resources.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/roles.ini':
        ensure => present,
        content => template('icinga2/web/roles.ini.erb'),
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
        content  => template('icinga2/web/backends.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/modules/monitoring'],
    }

    file { '/etc/icingaweb2/modules/monitoring/commandtransports.ini':
        ensure  => present,
        content => template('icinga2/web/commandtransports.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/modules/monitoring'],
    }

    include ssl::wildcard

    nginx::site { 'icinga2':
        ensure  => present,
        source  => 'puppet:///modules/icinga2/web/nginx/icinga2.conf',
        notify  => Exec['nginx-syntax-icinga'],
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
}
