# === Class role::mediawiki
class role::mediawiki (
    Boolean $strict_firewall = lookup('role::mediawiki::use_strict_firewall', {'default_value' => false}),
    Boolean $use_mcrouter = lookup('role::mediawiki::use_mcrouter', {'default_value' => false})
) {
    include prometheus::exporter::cadvisor

    if $use_mcrouter {
        include role::mediawiki::mcrouter
    } else {
        include role::mediawiki::nutcracker
    }
    include mediawiki

    if $strict_firewall {
        $firewall_rules_str = join(
            query_facts('Class[Role::Mediawiki] or Class[Role::Varnish] or Class[Role::Icinga2] or Class[Role::Prometheus] or Class[Role::Bastion]', ['networking'])
            .map |$key, $value| {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
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
    } else {
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
    }

    # Temporarily set vm.swappiness to 1 to handle
    # sudden cases where there's a spike in memory usage.
    # This is when all ram is used for a minute and need to use swap.
    sysctl::parameters { 'vm_swappiness':
        values => {
            'vm.swappiness' => 1,
        },
    }

    # Using fastcgi we need more local ports
    sysctl::parameters { 'raise_port_range':
        values   => { 'net.ipv4.ip_local_port_range' => '22500 65535', },
        priority => 90,
    }

    # Allow sockets in TIME_WAIT state to be re-used.
    # This helps prevent exhaustion of ephemeral port or conntrack sessions.
    # See <http://vincent.bernat.im/en/blog/2014-tcp-time-wait-state-linux.html>
    sysctl::parameters { 'tcp_tw_reuse':
        values => { 'net.ipv4.tcp_tw_reuse' => 1 },
    }

    motd::role { 'role::mediawiki':
        description => 'MediaWiki server',
    }
}
