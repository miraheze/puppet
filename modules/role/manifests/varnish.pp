# role: varnish
class role::varnish {
    include ::varnish
    include prometheus::exporter::varnishreqs

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

    $firewall_rules_str = join(
        query_facts('Class[Role::Mediawiki]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
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
