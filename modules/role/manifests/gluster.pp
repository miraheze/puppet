# role: gluster
class role::gluster {
    include ::gluster

    $firewall_rules = query_facts('Class[Role::Mediawiki] or Class[Role::Icinga2] or Class[Role::Gluster]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'gluster 24007':
        proto   => 'tcp',
        port    => '24007',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    ferm::service { 'gluster 24008':
        proto   => 'tcp',
        port    => '24008',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    ferm::service { 'gluster 24009':
        proto   => 'tcp',
        port    => '24009',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    ferm::service { 'gluster 111':
        proto  => 'tcp',
        port   => '111',
        srange => "(${firewall_rules_str})",
    }

    ferm::service { 'gluster 49152':
        proto   => 'tcp',
        port    => '49152',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    ferm::service { 'gluster 49153':
        proto   => 'tcp',
        port    => '49153',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    ferm::service { 'gluster 49154':
        proto   => 'tcp',
        port    => '49154',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    motd::role { 'role::gluster':
        description => 'A file storage network solution.',
    }
}
