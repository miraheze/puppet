class prometheus::exporter::apache {
    stdlib::ensure_packages('prometheus-apache-exporter')

    file { '/etc/default/prometheus-apache-exporter':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => 'ARGS="--scrape_uri http://127.0.0.1:9006/server-status/?auto"',
        notify  => Service['prometheus-apache-exporter'],
    }

    service { 'prometheus-apache-exporter':
        ensure  => running,
        require => Package['prometheus-apache-exporter'],
    }

    $subquery = @("PQL")
    resources { type = 'Class' and title = 'Prometheus' }
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)
    ferm::service { 'prometheus apache exporter':
        proto  => 'tcp',
        port   => '9117',
        srange => "(${firewall_rules_str})",
    }
}
