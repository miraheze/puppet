# role: matomo
class role::matomo {

    include prometheus::exporter::redis
    class { '::redis':
        maxmemory_policy => 'allkeys-lru',
        password         => lookup('passwords::redis::master')
    }
    include ::matomo

    $subquery = @("PQL")
    (resources { type = 'Class' and title = 'Role::Varnish' } or
    resources { type = 'Class' and title = 'Role::Cache::Cache' } or
    resources { type = 'Class' and title = 'Role::Icinga2' })
    | PQL
    $firewall_srange = vmlib::generate_firewall_ip($subquery)
    firewall::service { 'http':
        proto   => 'tcp',
        port    => 80,
        srange  => "(${firewall_srange})",
        notrack => true,
    }

    firewall::service { 'https':
        proto   => 'tcp',
        port    => 443,
        srange  => "(${firewall_srange})",
        notrack => true,
    }

    system::role { 'matomo':
        description => 'analytics server',
    }
}
