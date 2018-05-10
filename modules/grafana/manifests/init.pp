# class: grafana
class grafana(
    # use php7.0 on stretch+
    $modules = ['headers', 'proxy', 'proxy_http', 'php5', 'rewrite', 'ssl']
) {
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

    if os_version('debian >= stretch') {
        $php_version = '7.0'
    } else {
        $php_version = '5'
    }

    require_package("libapache2-mod-php${php_version}")

    file { '/etc/apache2/sites-enabled/apache.conf':
        ensure => absent,
    }

    file { '/etc/grafana/grafana.ini':
        source   => 'puppet:///modules/grafana/grafana.ini',
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

    if os_version('debian >= stretch') {
        file { "/etc/php/${php_version}/apache2/conf.d/php.ini":
            ensure  => present,
            mode    => '0755',
            source  => 'puppet:///modules/grafana/apache/php7.ini',
            require => Package["libapache2-mod-php${$php_version}"]
        }
    } else {
        file { '/etc/php5/apache2/php.ini':
            ensure  => present,
            mode    => '0755',
            source  => 'puppet:///modules/grafana/apache/php.ini',
            require => Package["libapache2-mod-php${$php_version}"]
        }
    }

    httpd::mod { 'grafana_apache':
        modules => $modules,
        require => Package["libapache2-mod-php${php_version}"],
    }
}
