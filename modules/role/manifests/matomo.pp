# role: matomo
class role::matomo (
    Boolean $enable_redis = lookup('role::matomo::enable_redis', {'default_value' => false}),
) {

    if $enable_redis {
        include prometheus::exporter::redis
        class { '::redis':
            maxmemory_policy => 'allkeys-lru',
            password         => lookup('passwords::redis::master')
        }
    }

    include ::matomo

    firewall::service { 'http':
        proto    => 'tcp',
        port     => 80,
        src_sets => ['VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
        notrack  => true,
    }

    firewall::service { 'https':
        proto    => 'tcp',
        port     => 443,
        src_sets => ['VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
        notrack  => true,
    }

    $subquery_for_redis = @("PQL")
    (resources { type = 'Class' and title = 'Role::Matomo' })
    | PQL
    $firewall_srange_redis = vmlib::generate_firewall_ip($subquery)
    firewall::service { 'redis':
        proto   => 'tcp',
        port    => 6379,
        srange  => "(${firewall_srange_redis})",
        notrack => true,
    }

    system::role { 'matomo':
        description => 'analytics server',
    }
}
