# class: grafana
class grafana(
    # use php7.0 on stretch+
    $modules = ['headers', 'proxy', 'proxy_http', 'php7.0', 'rewrite', 'ssl']
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

    require_package(['graphite-web', 'graphite-carbon', 'graphite-api'])

    file { '/etc/default/graphite-carbon':
        source   => 'puppet:///modules/grafana/graphite-carbon',
        owner   => 'root',
        group   => 'root',
        require => Package['graphite-carbon'],
    }

    file { '/etc/graphite/local_settings.py':
        source   => 'puppet:///modules/grafana/local_settings.py',
        owner   => 'root',
        group   => 'root',
        require => [Package['graphite-api'], File['/etc/default/graphite-carbon']],
    }

    require_package('libapache2-mod-php7.0')

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

    service { 'carbon-cache':
        ensure => 'running',
        enable => true,
        subscribe => File['/etc/graphite/local_settings.py'],
        require   => Package['graphite-carbon'],
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

    file { '/etc/php/7.0/apache2/conf.d/php.ini':
        ensure  => present,
        mode    => '0755',
        source  => 'puppet:///modules/grafana/apache/php7.ini',
        require => Package["libapache2-mod-php7.0"]
    }

    httpd::mod { 'grafana_apache':
        modules => $modules,
        require => Package['libapache2-mod-php7.0'],
    }
}
