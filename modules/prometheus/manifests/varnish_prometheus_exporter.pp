class prometheus::varnish_prometheus_exporter (
    String $listen_port = '9131',
) {
    require_package('prometheus-varnish-exporter')

    systemd::service { 'prometheus-varnish-exporter':
        ensure  => present,
        content => systemd_template('prometheus-varnish-exporter'),
        restart => true,
        require => Package['varnish'],
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
