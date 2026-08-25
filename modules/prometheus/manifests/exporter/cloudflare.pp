class prometheus::exporter::cloudflare {
    $cf_api_token = lookup('passwords::cloudflare::api_token')

    file { '/etc/default/prometheus-cloudflare-exporter':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => "ARGS=\"--cf_api_token='${cf_api_token}' --listen :9119\"",
        notify  => Service['prometheus-cloudflare-exporter'],
    }


    systemd::service { 'prometheus-cloudflare-exporter':
        ensure  => present,
        content => systemd_template('cloudflare'),
    }

    firewall::service { 'prometheus cloudflare exporter':
        proto  => 'tcp',
        port   => 9119,
        src_sets => ['PROMETHEUS_HOSTS'],
    }
}
