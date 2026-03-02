# === Role eventgate
class role::eventgate {
    include eventgate

    # TODO: Restrict beta access at some point once we get this working.
    $subquery = @("PQL")
    (resources { type = 'Class' and title = 'Role::Mediawiki' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_task' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_beta' } or
    resources { type = 'Class' and title = 'Role::Icinga2' })
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)
    ferm::service { 'eventgate':
        proto   => 'tcp',
        port    => '8192',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    $subquery_2 = @("PQL")
    resources { type = 'Class' and title = 'Role::Prometheus' }
    | PQL
    $firewall_rules_prometheus_str = vmlib::generate_firewall_ip($subquery_2)
    ferm::service { 'eventgate-prometheus':
        proto   => 'tcp',
        port    => '9102',
        srange  => "(${firewall_rules_prometheus_str})",
        notrack => true,
    }

    system::role { 'role::eventgate':
        description => 'EventGate server',
    }
}
