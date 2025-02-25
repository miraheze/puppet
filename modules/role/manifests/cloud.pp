# class: role::cloud
class role::cloud {
    include ::cloud

    class { '::cpufrequtils': }

    $subquery = @("PQL")
    resources { type = 'Class' and title = 'Role::Cloud' }
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)

    ferm::service { 'proxmox port 5900:5999':
        proto  => 'tcp',
        port   => '5900:5999',
        srange => "(${firewall_rules_str})",
    }

    ferm::service { 'proxmox port 5404:5405':
        proto  => 'udp',
        port   => '5404:5405',
        srange => "(${firewall_rules_str})",
    }

    ferm::service { 'proxmox port 3128':
        proto  => 'tcp',
        port   => '3128',
        srange => "(${firewall_rules_str})",
    }

    ferm::service { 'proxmox port 8006':
        proto  => 'tcp',
        port   => '8006',
        srange => "(${firewall_rules_str})",
    }

    ferm::service { 'proxmox port 111':
        proto  => 'tcp',
        port   => '111',
        srange => "(${firewall_rules_str})",
    }

    system::role { 'cloud':
        description => 'Proxmox host',
    }
}
