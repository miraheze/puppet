# role: dns
class role::dns {
    include dns
    stdlib::ensure_packages('python3-dnspython')

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

    ferm::service { 'dns_udp':
        proto   => 'udp',
        notrack => true,
        prio    => 5,
        port    => '53',
    }

    ferm::service { 'dns_tcp':
        proto   => 'tcp',
        notrack => true,
        prio    => 5,
        port    => '53',
    }

    system::role { 'dns':
        description => 'authoritative DNS server',
    }
}
