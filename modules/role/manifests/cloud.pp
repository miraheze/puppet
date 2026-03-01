# class: role::cloud
class role::cloud {
    include ::cloud

    class { '::cpufrequtils': }

    $subquery = @("PQL")
    resources { type = 'Class' and title = 'Role::Cloud' }
    | PQL
    $firewall_rules_str = join(
        puppetdb::query_facts(
            ['networking'],
            $subquery
        ).values.map |$_facts| {
            if ( $_facts['networking']['interfaces']['vmbr1'] ) {
                "${_facts['networking']['interfaces']['vmbr1']['ip']} ${_facts['networking']['ip']} ${_facts['networking']['ip6']}"
            } else {
                "${_facts['networking']['ip']} ${_facts['networking']['ip6']}"
            }
        }.flatten.sort.unique,
        ' '
    )

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
