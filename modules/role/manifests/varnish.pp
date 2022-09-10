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

    # tcp_tw_(reuse|recycle): both are off by default
    # http://vincent.bernat.im/en/blog/2014-tcp-time-wait-state-linux.html
    #    _recycle is dangerous: it violates RFCs, and probably breaks
    # clients when many clients are behind a single NAT gateway, and
    # affects the recycling of TIME_WAIT slots for both incoming and
    # outgoing connections.
    #    _reuse is not-so-dangerous: it only affects outgoing
    # connections, and looks at timestamp and other state information to
    # gaurantee that the reuse doesn't cause issues within reasonable
    # constraints.
    #    This helps prevent TIME_WAIT issues for our $localip<->$localip
    # connections from nginx to varnish:80 - some of our caches reach
    # connection volume/rate spikes where this is a real issue.
    sysctl::parameters { 'tcp_tw_reuse':
        values => { 'net.ipv4.tcp_tw_reuse' => 1 },
    }

    motd::role { 'role::varnish':
        description => 'Varnish caching server',
    }
}
