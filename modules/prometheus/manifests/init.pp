# class: prometheus
class prometheus {

    require_package('prometheus')

    $host = query_nodes("domain='$domain'", 'fqdn')
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

    if hiera('base::monitoring::use_icinga2', false) {
        icinga2::custom::services { 'Prometheus':
            check_command => 'tcp',
            vars          => {
                tcp_port    => '9090',
            },
        }
    } else {
        icinga::service { 'prometheus':
            description   => 'Prometheus',
            check_command => 'check_tcp!9090',
        }
    }
}
