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

    $subquery = @("PQL")
    resources { type = 'Class' and title = 'Role::Prometheus' }
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)
    ferm::service { 'prometheus cloudflare exporter':
        proto  => 'tcp',
        port   => '9119',
        srange => "(${firewall_rules_str})",
    }
}
