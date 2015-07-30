class role::ganglia {
    include ::ganglia

    ufw::allow { 'ganglia udp':
        proto => 'udp',
        port  => 8649,
    }

    ufw::allow { 'ganglia tcp':
        proto => 'tcp',
        port  => 8649,
    }

    motd::role { 'role::ganglia':
        description => 'central Ganglia server',
    }
}
