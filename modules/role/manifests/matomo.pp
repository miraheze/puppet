# role: matomo
class role::matomo (
    String $enable_redis = lookup('role::matomo::enable_redis', {'default_value' => false}),
) {

    if $enable_redis {
        include prometheus::exporter::redis
        class { '::redis':
            maxmemory_policy => 'allkeys-lru',
            password         => lookup('passwords::redis::master')
        }
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

    $subquery_for_redis = @("PQL")
    (resources { type = 'Class' and title = 'Role::Matomo' })
    | PQL
    $firewall_srange = vmlib::generate_firewall_ip($subquery)
    firewall::service { 'redis':
        proto   => 'tcp',
        port    => 6379,
        srange  => "(${firewall_srange})",
        notrack => true,
    }

    system::role { 'matomo':
        description => 'analytics server',
    }
}
