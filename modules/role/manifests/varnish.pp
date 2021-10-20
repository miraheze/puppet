# role: varnish
class role::varnish {
    include ::varnish

    ferm::service { 'http':
        proto   => 'tcp',
        port    => '80',
        notrack => true,
    }

    ferm::service { 'https':
        proto   => 'tcp',
        port    => '443',
        notrack => true,
    }

    $firewall_rules = query_facts('Class[Role::Mediawiki]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'direct varnish access':
        proto   => 'tcp',
        port    => '81',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    motd::role { 'role::varnish':
        description => 'Varnish caching server',
    }
}
