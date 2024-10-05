class prometheus::exporter::cloudflare {
    $cf_api_token = lookup('passwords::cloudflare::api_token')

    file { '/etc/default/prometheus-cloudflare-exporter':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => "ARGS=\"--metrics_path '' --cf_api_token='${cf_api_token}' --listen :9119\"",
        notify  => Service['prometheus-cloudflare-exporter'],
    }


    systemd::service { 'prometheus-cloudflare-exporter':
        ensure  => present,
        content => systemd_template('cloudflare'),
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Prometheus]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'prometheus cloudflare exporter':
        proto  => 'tcp',
        port   => '9119',
        srange => "(${firewall_rules_str})",
    }
}
