# class: role::cloud
class role::cloud {
    include cloud

    class { 'cpupower': }


    firewall::service { 'proxmox port 5900:5999':
        proto      => 'tcp',
        port_range => [5900, 5999],
        src_sets   => ['CLOUD_HOSTS'],
    }

    firewall::service { 'proxmox port 5404:5405':
        proto      => 'udp',
        port_range => [5404, 5405],
        src_sets   => ['CLOUD_HOSTS'],
    }

    firewall::service { 'proxmox port 3128':
        proto    => 'tcp',
        port     => 3128,
        src_sets => ['CLOUD_HOSTS'],
    }

    firewall::service { 'proxmox port 8006':
        proto    => 'tcp',
        port     => 8006,
        src_sets => ['CLOUD_HOSTS'],
    }

    firewall::service { 'proxmox port 111':
        proto    => 'tcp',
        port     => 111,
        src_sets => ['CLOUD_HOSTS'],
    }

    system::role { 'cloud':
        description => 'Proxmox host',
    }
}
