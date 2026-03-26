# role: chart
# copy-pasted from mathoid
class role::chart {
    include chart

    if ($facts['networking']['hostname'] =~ /^test.+$/) {
        $subquery = @("PQL")
        (resources { type = 'Class' and title = 'Role::Bastion' } or
        resources { type = 'Class' and title = 'Role::Mediawiki_beta' } or
        resources { type = 'Class' and title = 'Role::Icinga2' })
        | PQL
    } else {
        $subquery = @("PQL")
        (resources { type = 'Class' and title = 'Role::Bastion' } or
        resources { type = 'Class' and title = 'Role::Mediawiki' } or
        resources { type = 'Class' and title = 'Role::Mediawiki_task' } or
        resources { type = 'Class' and title = 'Role::Icinga2' })
        | PQL
    }
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)
    ferm::service { 'chart':
        proto   => 'tcp',
        port    => '6284',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    system::role { 'chart':
        description => 'Chart server',
    }
}
