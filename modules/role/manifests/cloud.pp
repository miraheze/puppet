# class: role::cloud
class role::cloud {
    include ::cloud

    class { '::cpufrequtils': }

    $firewall_rules_str = join(
        query_facts('Class[Role::Cloud]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
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

    motd::role { 'role::cloud':
        description => 'cloud virts to host own vps using proxmox',
    }
}
