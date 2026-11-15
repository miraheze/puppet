# class: role::cloud
class role::cloud {
    include cloud

    class { 'cpupower': }

    $subquery = @("PQL")
    resources { type = 'Class' and title = 'Role::Cloud' }
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)

    firewall::service { 'proxmox port 5900:5999':
        proto      => 'tcp',
        port_range => [5900, 5999],
        srange     => "(${firewall_rules_str})",
    }

    firewall::service { 'proxmox port 5404:5405':
        proto      => 'udp',
        port_range => [5404, 5405],
        srange     => "(${firewall_rules_str})",
    }

    firewall::service { 'proxmox port 3128':
        proto  => 'tcp',
        port   => 3128,
        srange => "(${firewall_rules_str})",
    }

    firewall::service { 'proxmox port 8006':
        proto  => 'tcp',
        port   => 8006,
        srange => "(${firewall_rules_str})",
    }

    firewall::service { 'proxmox port 111':
        proto  => 'tcp',
        port   => 111,
        srange => "(${firewall_rules_str})",
    }

    system::role { 'cloud':
        description => 'Proxmox host',
    }
}
