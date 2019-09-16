# class: prometheus
class prometheus {

    if os_version('debian == stretch') {
        apt::pin { 'debian_stretch_backports_prometheus':
            priority   => 740,
            originator => 'Debian',
            release    => 'stretch-backports',
            packages   => 'prometheus',
        }
    }

    require_package('prometheus')

    file { '/etc/default/prometheus':
        source  => 'puppet:///modules/prometheus/prometheus.default.conf',
        owner   => 'root',
        group   => 'root',
        notify  => Service['prometheus'],
        require => Package['prometheus'],
    }

    $host = query_nodes("domain='$domain'", 'fqdn')
    $host_nginx = query_nodes("domain='$domain' and Class[Prometheus::Nginx]", 'fqdn')
    $host_php_fpm = query_nodes("domain='$domain' and Class[Php::Php_fpm]", 'fqdn')
    file { '/etc/prometheus/prometheus.yml':
        content => template('prometheus/prometheus.yml.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service['prometheus'],
        require => Package['prometheus'],
    }

    service { 'prometheus':
        ensure    => running,
        require   => Package['prometheus'],
    }

    monitoring::services { 'Prometheus':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '9090',
        },
    }
}
