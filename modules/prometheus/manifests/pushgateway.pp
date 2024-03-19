class prometheus::pushgateway (
    VMlib::Ensure $ensure = present,
    Stdlib::Port  $listen_port = 9091,
    String        $vhost = 'prometheus-pushgateway.wikitide.net',
) {
    stdlib::ensure_packages('prometheus-pushgateway')

    # Apache config
    class { '::httpd':
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
        content  => template('prometheus/pushgateway-apache.erb'),
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
