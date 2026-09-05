class prometheus::exporter::varnish (
    String $listen_port = '9131',
) {
    stdlib::ensure_packages('prometheus-varnish-exporter')

    systemd::service { 'prometheus-varnish-exporter':
        ensure  => present,
        content => systemd_template('prometheus-varnish-exporter', { 'listen_port' => $listen_port }),
        restart => true,
    }

    firewall::service { 'prometheus varnish_exporter':
        proto      => 'tcp',
        port_range => [Integer($listen_port), Integer($listen_port)],
        src_sets   => ['PROMETHEUS_HOSTS'],
    }
}
