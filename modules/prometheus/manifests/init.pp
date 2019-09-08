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

    $host_ip = query_nodes("domain='$domain'", 'ipaddress')
    $host_nginx = query_nodes("domain='$domain' and Class[Prometheus::Nginx]", 'fqdn')
    $host_php_fpm = query_nodes("domain='$domain' and Class[Php::Php_fpm]", 'fqdn')
    file { '/etc/prometheus/prometheus.yml':
        content => template('prometheus/prometheus.yml.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['prometheus'],
    }

    service { 'prometheus':
        ensure    => running,
        require   => Package['prometheus'],
        subscribe => File['/etc/prometheus/prometheus.yml'],
    }

    monitoring::services { 'Prometheus':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '9090',
        },
    }
}
