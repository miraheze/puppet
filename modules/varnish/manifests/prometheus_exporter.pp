class varnish::prometheus_exporter (
    $listen_port = '9131',
) {
    require_package('prometheus-varnish-exporter')

    exec { 'prometheus-varnish-exporter reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/prometheus-varnish-exporter.service':
        ensure  => present,
        content  => template('varnish/prometheus-varnish-exporter.systemd'),
        notify  => Exec['prometheus-varnish-exporter reload systemd']',
    }

    service { 'prometheus-varnish-exporter':
        ensure  => 'running',
        require => [ Package['varnish'], File['/etc/systemd/system/prometheus-varnish-exporter.service'] ],
    }

    ufw::allow { 'prometheus varnish/misc2':
        proto   => 'tcp',
        port    => $listen_port,
        from    => '81.4.127.174',
    }   
}
