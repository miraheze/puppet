class prometheus::exporter::cadvisor {
    stdlib::ensure_packages('cadvisor')

    systemd::service { 'cadvisor':
        content   => init_template('cadvisor', 'systemd_override'),
        override  => true,
        restart   => true,
        subscribe => Package['cadvisor'],
    }

    $firewall_rules_str = join(
        query_facts("networking.domain='${facts['networking']['domain']}' and Class[Prometheus] or Class[Role::Grafana]", ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'prometheus cadvisor_exporter':
        proto  => 'tcp',
        port   => '4194',
        srange => "(${firewall_rules_str})",
    }
}
