# role: dns
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

    ufw::allow { 'dns monitor tcp':
        proto => 'tcp',
        port  => 3506,
        from  => '185.52.1.76',
    }

    motd::role { 'role::dns':
        description => 'authoritative DNS server',
    }
}
