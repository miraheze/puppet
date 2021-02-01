class prometheus::varnish_prometheus_exporter (
    String $listen_port = '9131',
) {
    require_package('prometheus-varnish-exporter')

    exec { 'prometheus-varnish-exporter reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/prometheus-varnish-exporter.service':
        ensure  => present,
        content  => template('prometheus/prometheus-varnish-exporter.systemd'),
        notify  => Exec['prometheus-varnish-exporter reload systemd'],
    }

    service { 'prometheus-varnish-exporter':
        ensure  => 'running',
        require => [ Package['varnish'], File['/etc/systemd/system/prometheus-varnish-exporter.service'] ],
    }

    $firewall = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "prometheus ${listen_port} ${value['ipaddress']}":
            proto => 'tcp',
            port  => $listen_port,
            from  => $value['ipaddress'],
        }

        ufw::allow { "prometheus ${listen_port} ${value['ipaddress6']}":
            proto => 'tcp',
            port  => $listen_port,
            from  => $value['ipaddress6'],
        }
    }
}
