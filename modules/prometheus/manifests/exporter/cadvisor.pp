class prometheus::exporter::cadvisor {
    stdlib::ensure_packages('cadvisor')

    systemd::service { 'cadvisor':
        content   => init_template('cadvisor', 'systemd_override'),
        override  => true,
        restart   => true,
        subscribe => Package['cadvisor'],
    }

    $subquery = @("PQL")
    resources { type = 'Class' and title = 'Prometheus' }
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)
    ferm::service { 'prometheus cadvisor_exporter':
        proto  => 'tcp',
        port   => '4194',
        srange => "(${firewall_rules_str})",
    }
}
