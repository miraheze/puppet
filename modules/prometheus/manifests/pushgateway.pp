class prometheus::pushgateway (
    VMlib::Ensure $ensure = present,
    Stdlib::Port  $listen_port = 9091,
    String        $vhost = 'prometheus-pushgateway.fsslc.wtnet',
) {
    stdlib::ensure_packages('prometheus-pushgateway')

    # Apache config
    class { 'httpd':
        modules => [
            'proxy',
            'proxy_http',
            'rewrite',
            'headers',
            'allowmethods',
        ],
    }

    httpd::site { 'pushgateway':
        priority => 30, # Earlier than main prometheus* vhost wildcard matching
        content  => epp('prometheus/pushgateway-apache.epp', { 'vhost' => $vhost, 'listen_port' => $listen_port }),
    }

    systemd::service { 'prometheus-pushgateway':
        ensure         => $ensure,
        restart        => true,
        content        => systemd_template('prometheus-pushgateway', { 'listen_port' => $listen_port }),
        service_params => {
            hasrestart => true,
        },
    }
}
