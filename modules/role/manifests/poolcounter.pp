# role: poolcounter
class role::poolcounter {
    include poolcounter

    if ( $facts['networking']['hostname'] =~ /^test1.+$/ ) {
        $subquery = @("PQL")
        (resources { type = 'Class' and title = 'Role::Mediawiki_beta' } or
        resources { type = 'Class' and title = 'Role::Icinga2' })
        | PQL
    } else {
        $subquery = @("PQL")
        (resources { type = 'Class' and title = 'Role::Mediawik' } or
        resources { type = 'Class' and title = 'Role::Mediawiki_task' } or
        resources { type = 'Class' and title = 'Role::Icinga2' })
        | PQL
    }
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)

    ferm::service { 'poolcounter':
        proto   => 'tcp',
        port    => '7531',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    monitoring::nrpe { 'poolcounter process':
        command => '/usr/lib/nagios/plugins/check_procs -c 1:1 -u poolcounter -C poolcounterd',
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#Poolcounter'
    }

    system::role { 'poolcounter':
        description => 'Poolcounter server',
    }
}
