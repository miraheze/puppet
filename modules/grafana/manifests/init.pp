# class: grafana
class grafana(
    # use php7.0 on stretch+
    $modules = ['headers', 'proxy', 'proxy_http', 'php7.0', 'rewrite', 'ssl'],
    $php_72 = false,
) {
    $grafana_password = hiera('passwords::db::grafana')

    include ::httpd

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

    if $php_72 {
        include ::php

        $php = '7.2'
    } else {
        $php = '7.0'
    }

    require_package("libapache2-mod-php${php}")

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

    httpd::site { 'grafana.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/grafana/apache/apache.conf',
        require => File['/etc/apache2/sites-enabled/apache.conf'],
        monitor => true,
    }

    file { "/etc/php/${php}/apache2/conf.d/php.ini":
        ensure  => present,
        mode    => '0755',
        source  => 'puppet:///modules/grafana/apache/php.ini',
        require => Package["libapache2-mod-php${$php}"]
    }

    httpd::mod { 'grafana_apache':
        modules => $modules,
        require => Package["libapache2-mod-php${php}"],
        monitor => true,
    }
}
