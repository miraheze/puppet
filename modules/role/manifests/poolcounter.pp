# role: redis
class role::redis {
    include poolcounter

    $firewall_rules_str = join(
        query_facts("networking.domain='${facts['networking']['domain']}' and (Class[Role::Mediawiki] or Class[Role::Icinga2])", ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'poolcounter':
        proto   => 'tcp',
        port    => '7531',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    motd::role { 'role::poolcounter':
        description => 'Poolcounter server',
    }
}
