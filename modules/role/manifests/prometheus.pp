# role: prometheus
class role::prometheus {
    include ::prometheus
    include prometheus::blackbox_exporter

    $firewall_rules = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'prometheus':
        proto  => 'tcp',
        port   => '9090',
        srange => "(${firewall_rules_str})",
    }

    motd::role { 'role::prometheus':
        description => 'central Prometheus server',
    }
}
