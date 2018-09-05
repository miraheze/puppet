# class: grafana
class grafana {

    $grafana_password = hiera('passwords::db::grafana')

    include ssl::wildcard

    include ::apt

    apt::source { 'grafana_apt':
        comment  => 'Grafana stable',
        location => 'https://packagecloud.io/grafana/stable/debian/',
        release  => "${::lsbdistcodename}",
        repos    => 'main',
        key      => 'F86AA916A2195E121AEDB11437BBEE3F7AD95B3F',
    }

    package { 'grafana':
        ensure  => present,
        require => Apt::Source['grafana_apt'],
    }

    include ::php

    require_package('libapache2-mod-php7.2')

    file { '/etc/apache2/sites-enabled/apache.conf':
        ensure => absent,
    }
    
    $mail_password = hiera('passwords::mail::noreply')

    file { '/etc/grafana/grafana.ini':
        content => template('grafana/grafana.ini.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['grafana'],
    }

    service { 'grafana-server':
        ensure => 'running',
        enable => true,
        subscribe => [
            File['/etc/grafana/grafana.ini'],
            Package['grafana'],
        ],
    }

    nginx::site { 'grafana.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/grafana/nginx/grafana.conf',
        notify  => Exec['nginx-syntax-grafana'],
    }

    file { '/etc/php/7.2/fpm/conf.d/php.ini':
        ensure  => present,
        mode    => '0755',
        source  => 'puppet:///modules/grafana/nginx/php.ini',
        require => Package['libapache2-mod-php7.2']
    }

    exec { 'nginx-syntax-grafana':
        command     => '/usr/sbin/nginx -t',
        notify      => Exec['nginx-reload-grafana'],
        refreshonly => true,
    }

    exec { 'nginx-reload-grafana':
        command     => '/usr/sbin/service nginx reload',
        refreshonly => true,
        require     => Exec['nginx-syntax-grafana'],
    }

    icinga2::custom::services { 'grafana.miraheze.org HTTPS':
         check_command => 'check_http',
         vars          => {
             http_ssl   => true,
             http_vhost => 'grafana.miraheze.org',
         },
     }
}
