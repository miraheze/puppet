class prometheus::pushgateway (
    VMlib::Ensure $ensure = present,
    Stdlib::Port  $listen_port = 9091,
    String        $vhost = 'prometheus-pushgateway.wikitide.net',
) {
    stdlib::ensure_packages('prometheus-pushgateway')

    nginx::site { 'pushgateway':
        content  => template('prometheus/pushgateway-nginx.erb'),
    }

    systemd::service { 'prometheus-pushgateway':
        ensure         => $ensure,
        restart        => true,
        content        => systemd_template('prometheus-pushgateway'),
        service_params => {
            hasrestart => true,
        },
    }
}
