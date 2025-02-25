# === Role changeprop
class role::changeprop {
    include changeprop
    include role::prometheus::statsd_exporter

    # TODO: Restrict beta access at some point once we get working.
    $subquery = @("PQL")
    (resources { type = 'Class' and title = 'Role::Mediawik' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_task' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_beta' } or
    resources { type = 'Class' and title = 'Role::Icinga2' })
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)

    ferm::service { 'changeprop':
        proto   => 'tcp',
        port    => '7200',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    system::role { 'role::changeprop':
        description => 'ChangeProp server',
    }
}
