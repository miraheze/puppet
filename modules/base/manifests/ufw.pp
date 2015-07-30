# firewall for all servers
class base::ufw {
    include ::ufw

    ufw::allow { 'ssh':
        proto => 'tcp',
        port  => 22,
    }

    ufw::allow { 'nrpe':
        proto => 'tcp',
        port  => 5666,
    }

    ufw::allow { 'ganglia udp':
        proto => 'udp',
        port  => 8649,
    }

    ufw::allow { 'ganglia tcp':
        proto => 'tcp',
        port  => 8649,
    }
}
