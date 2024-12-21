# role: redis
class role::redis {
    include prometheus::exporter::redis

    $redis_heap = lookup('redis::heap', {'default_value' => '7000mb'})
    class { '::redis':
        persist   => false,
        password  => lookup('passwords::redis::master'),
        maxmemory => $redis_heap,
    }

    if ( $facts['networking']['hostname'] =~ /^test1.+$/  ) {
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

    ferm::service { 'redis':
        proto   => 'tcp',
        port    => '6379',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    system::role { 'redis':
        description => 'Redis caching server',
    }
}
