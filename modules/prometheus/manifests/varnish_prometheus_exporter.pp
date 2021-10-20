class prometheus::varnish_prometheus_exporter (
    String $listen_port = '9131',
) {
    require_package('prometheus-varnish-exporter')

    systemd::service { 'prometheus-varnish-exporter':
        ensure  => present,
        content => systemd_template('prometheus-varnish-exporter'),
        restart => true,
    }

    $firewall_rules = query_facts('Class[Role::Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'prometheus varnish_exporter':
        proto  => 'tcp',
        port   => $listen_port,
        srange => "(${firewall_rules_str})",
    }
}
