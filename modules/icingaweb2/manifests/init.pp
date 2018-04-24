class icingaweb2(
    $icingaweb_db_host = hiera('icingaweb_db_host', 'db4.miraheze.org'),
    $icingaweb_db_name = hiera('icingaweb_db_name', 'icingaweb2'),
    $icingaweb_user_name = hiera('icingaweb_user_name', 'icingaweb2'),
    $icingaweb_password = hiera('passwords::icingaweb2'),
    $icinga_ido_db_host = hiera('icinga_ido_db_host', 'db4.miraheze.org'),
    $icinga_ido_db_name = hiera('icinga_ido_db_name', 'icinga'),
    $icinga_ido_user_name = hiera('icinga_ido_user_name', 'icinga2'),
    $icinga_ido_password = hiera('passwords::icinga_ido'),
    $icinga_api_password = hiera('passwords::icinga_api'),
    # use php7.2 on stretch+
    $modules = ['alias', 'headers', 'rewrite', 'php7.2', 'proxy', 'proxy_http', 'ssl'],
    $use_apache = hiera('icingaweb2::use_apache', true)
) {
    if $use_apache {
        include ::httpd
    }

    include ::php

    package { [ 'icingaweb2', 'icingaweb2-module-monitoring',
                'icingaweb2-module-doc', 'icingacli' ] :
        ensure => present,
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
        ensure => present,
        content => template('icingaweb2/groups.ini.erb'),
        owner  => 'www-data',
        group  => 'icingaweb2',
    }

    file { '/etc/icingaweb2/resources.ini':
        ensure => present,
        content => template('icingaweb2/resources.ini.erb'),
        owner  => 'www-data',
        group  => 'icingaweb2',
    }

    file { '/etc/icingaweb2/modules':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'icingaweb2',
        mode    => '2755',
        require => Package['icingaweb2'],
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

    # Temporarily supporting icinga under nginx
    if $use_apache {
      # change this back to icinga.miraheze.org once it works
      httpd::site { 'icinga2.miraheze.org':
          ensure  => present,
          source  => 'puppet:///modules/icingaweb2/apache/apache.conf',
          monitor => true,
      }

      httpd::mod { 'icinga_apache':
          modules => $modules,
          require => Package["libapache2-mod-php7.2"],
      }
    } else {
      nginx::site { 'icinga2':
          ensure  => present,
          source  => 'puppet:///modules/icingaweb2/nginx/icinga2.conf',
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
}
