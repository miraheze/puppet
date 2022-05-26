class prometheus::exporter::cadvisor {
    ensure_packages('cadvisor')

    systemd::service { 'cadvisor':
        content   => init_template('cadvisor', 'systemd_override'),
        override  => true,
        restart   => true,
        subscribe => Package['cadvisor'],
    }

    $firewall_rules = query_facts('Class[Prometheus] or Class[Role::Grafana]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'prometheus cadvisor_exporter':
        proto  => 'tcp',
        port   => '4194',
        srange => "(${firewall_rules_str})",
    }
}
