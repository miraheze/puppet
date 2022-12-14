# role: swift::proxy
class role::swift::proxy {

    include ::swift
    include ::swift::proxy
    include ::swift::ring

    class { 'memcached':
        size          => 128,
        port          => 11211,
        growth_factor => 1.05,
        min_slab_size => 5,
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Swift::Ac] or Class[Role::Swift::Proxy] or Class[Role::Swift::Storage] or Class[Role::Mediawiki] or Class[Role::Icinga2] or Class[Role::Prometheus]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

    ferm::service { 'http':
        proto   => 'tcp',
        port    => '80',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    ferm::service { 'https':
        proto   => 'tcp',
        port    => '443',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    ferm::service { 'swift_memcache_11211':
        proto   => 'tcp',
        port    => '11211',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    motd::role { 'role::swift::proxy':
        description => 'Openstack Swift Service Proxy',
    }
}
