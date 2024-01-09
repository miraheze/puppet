# role: mathoid
class role::mathoid {
    include mathoid

    $firewall_rules_str = join(
        query_facts('Class[Role::Mediawiki] or Class[Role::Icinga2]', ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'mathoid':
        proto   => 'tcp',
        port    => '10044',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    motd::role { 'role::mathoid':
        description => 'Mathoid server',
    }
}
