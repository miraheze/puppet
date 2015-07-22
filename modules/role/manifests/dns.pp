class role::dns {
    include ::dns

    ufw::allow { 'dns port udp':
        proto => 'udp',
        port  => 53,
    }

    ufw::allow { 'dns port tcp':
        proto => 'tcp',
        port  => 53,
    }

    motd::role { 'role::dns':
        description => 'authoritative DNS server',
    }
}
