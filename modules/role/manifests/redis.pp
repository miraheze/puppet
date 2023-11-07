# role: redis
class role::redis (
    $maxmemory = lookup('redis::heap', {'default_value' => '7000mb'}),
    $maxmemory_policy = lookup('redis::maxmemory_policy', {'default_value' => 'allkeys-lru'})
) {
    include prometheus::exporter::redis

    class { '::redis':
        persist   => false,
        password  => lookup('passwords::redis::master'),
        maxmemory => $maxmemory,
        maxmemory_policy => $maxmemory_policy,
    }

    $firewall_rules_str = join(
        query_facts("networking.domain='${facts['networking']['domain']}' and Class[Role::Mediawiki] or Class[Role::Icinga2]", ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'redis':
        proto   => 'tcp',
        port    => '6379',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    motd::role { 'role::redis':
        description => 'Redis caching server',
    }
}
