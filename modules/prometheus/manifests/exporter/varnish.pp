class prometheus::exporter::varnish (
    String $listen_port = '9131',
) {
    stdlib::ensure_packages('prometheus-varnish-exporter')

    systemd::service { 'prometheus-varnish-exporter':
        ensure  => present,
        content => systemd_template('prometheus-varnish-exporter'),
        restart => true,
    }

    $firewall_rules_str = join(
        query_facts("networking.domain='${facts['networking']['domain']}' and Class[Role::Prometheus]", ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'prometheus varnish_exporter':
        proto  => 'tcp',
        port   => $listen_port,
        srange => "(${firewall_rules_str})",
    }
}
