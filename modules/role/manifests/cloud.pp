# class: role::cloud
class role::cloud {
    class { '::cloud':
        main_interface     => lookup('role::cloud::main_interface', {'default_value' => 'eno0'}),
        main_ip4_address   => lookup('role::cloud::main_ip4_address'),
        main_ip4_netmask   => lookup('role::cloud::main_ip4_netmask'),
        main_ip4_broadcast => lookup('role::cloud::main_ip4_broadcast'),
        main_ip4_gateway   => lookup('role::cloud::main_ip4_gateway'),
        main_ip6_address   => lookup('role::cloud::main_ip6_address'),
        main_ip6_gateway   => lookup('role::cloud::main_ip6_gateway'),
        private_interface  => lookup('role::cloud::private_interface', {'default_value' => undef}),
        private_ip         => lookup('role::cloud::private_ip', {'default_value' => '0.0.0.0'}),
        private_netmask    => lookup('role::cloud::private_netmask', {'default_value' => undef}),
    }

    ferm::conf { 'forward-ferm':
        ensure => present,
        prio   => 20,
        source => 'puppet:///modules/role/cloud/forward-ferm',
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Cloud]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
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
