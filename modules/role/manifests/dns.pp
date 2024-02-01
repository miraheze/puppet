# role: dns
class role::dns {
    include ::dns

    $mem = $facts['memory']['system']['total_bytes'] / (1024.0 * 1024.0) / 1024.0
    # If less than 500mib change vm.swappiness to 1
    # fixes an issue on machines that only have 500mib available.
    if ($mem < 0.5) {
        sysctl::parameters { 'vm_swappiness':
            values => {
                'vm.swappiness' => 1,
            },
        }
    }

    package { 'python3-dnspython':
        ensure => latest
    }

    ferm::service { 'dns_udp':
        proto => 'udp',
        port  => '53',
    }

    ferm::service { 'dns_tcp':
        proto => 'tcp',
        port  => '53',
    }

    ferm::rule { 'skip_dns_conntrack-out':
        desc  => 'Skip DNS outgoing connection tracking',
        table => 'raw',
        chain => 'OUTPUT',
        rule  => 'proto udp sport 53 NOTRACK;',
    }

    ferm::rule { 'skip_dns_conntrack-in':
        desc  => 'Skip DNS incoming connection tracking',
        table => 'raw',
        chain => 'PREROUTING',
        rule  => 'proto udp dport 53 NOTRACK;',
    }

    motd::role { 'role::dns':
        description => 'authoritative DNS server',
    }
}
