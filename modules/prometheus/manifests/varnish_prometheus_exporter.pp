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

    ufw::allow { 'prometheus varnish/misc2':
        proto   => 'tcp',
        port    => $listen_port,
        from    => '185.52.3.121',
    }

    ufw::allow { 'prometheus varnish ipv4':
        proto => 'tcp',
        port  => $listen_port,
        from  => '51.89.160.138',
    }

    ufw::allow { 'prometheus varnish ipv6':
        proto => 'tcp',
        port  => $listen_port,
        from  => '2001:41d0:800:105a::6',
    }
}
