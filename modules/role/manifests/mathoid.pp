# role: mathoid
class role::mathoid {
    include mathoid

    if ( $facts['networking']['hostname'] =~ /^test1.+$/ ) {
        $subquery = @("PQL")
        (resources { type = 'Class' and title = 'Role::Bastion' } or
        resources { type = 'Class' and title = 'Role::Mediawiki_beta' } or
        resources { type = 'Class' and title = 'Role::Icinga2' })
        | PQL
    } else {
        $subquery = @("PQL")
        (resources { type = 'Class' and title = 'Role::Bastion' } or
        resources { type = 'Class' and title = 'Role::Mediawik' } or
        resources { type = 'Class' and title = 'Role::Mediawiki_task' } or
        resources { type = 'Class' and title = 'Role::Icinga2' })
        | PQL
    }
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)

    ferm::service { 'mathoid':
        proto   => 'tcp',
        port    => '10044',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    system::role { 'mathoid':
        description => 'Mathoid server',
    }
}
