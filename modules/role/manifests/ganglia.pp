# role: ganglia
class role::ganglia {
    include ::ganglia

    ufw::allow { 'icinga http':
        proto => 'tcp',
        port  => '80',
    }

    ufw::allow { 'icinga https':
        proto => 'tcp',
        port  => '443',
    }

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
