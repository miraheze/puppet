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

    sysctl::parameters { 'varnish increase connections':
        values => {
            'net.core.somaxconn' => 16384,
        }
    }

    sysctl::parameters { 'cache proxy network tuning':
        values => {
            # Increase the number of ephemeral ports
            'net.ipv4.ip_local_port_range'       => [ 4001, 65534 ],

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
            'net.ipv4.tcp_tw_reuse'              => 1,

            # tcp_slow_start_after_idle: SSR resets the congestion window of
            # connections that have gone idle, which means it has a tendency to
            # reset the congestion window of HTTP keepalive and HTTP/2
            # connections, which are characterized by short bursts of activity
            # separated by long idle times.
            'net.ipv4.tcp_slow_start_after_idle' => 0,

            # tcp_notsent_lowat: Default is -1 (unset).  The default behavior is
            # to keep the socket writeable until the whole socket buffer fills.
            # With this set, even if there's buffer space, the kernel doesn't
            # notify of writeability (e.g. via epoll()) until the amount of
            # unsent data (as opposed to unacked) in the socket buffer is less
            # than this value.  This reduces local buffer bloat on our server's
            # sending side, which may help with HTTP/2 prioritization.  The
            # magic value for tuning is debateable, but arguably even setting a
            # conservative (higher) value here is better than not setting it
            # all, in almost all cases for any kind of TCP traffic.  ~128K seems
            # to be a common recommendation for something close-ish to optimal
            # for internet-facing things.
            'net.ipv4.tcp_notsent_lowat'         => 131072,
        }
    }

    motd::role { 'role::varnish':
        description => 'Varnish caching server',
    }
}
