class prometheus::exporter::varnish (
    String $listen_port = '9131',
) {
    ensure_packages('prometheus-varnish-exporter')

    systemd::service { 'prometheus-varnish-exporter':
        ensure  => present,
        content => systemd_template('prometheus-varnish-exporter'),
        restart => true,
    }

    $firewall_rules_str = join(
        query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
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
