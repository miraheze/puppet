# role: swift::ac
class role::swift::ac {

    include ::swift
    include ::swift::ac
    include ::swift::ring

    $firewall_rules_str = join(
        query_facts('Class[Role::Swift::Ac] or Class[Role::Swift::Proxy] or Class[Role::Swift::Storage] or Class[Role::Mediawiki] or Class[Role::Icinga2] or Class[Role::Prometheus]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

    ferm::service { 'swift_account_6002':
        proto   => 'tcp',
        port    => '6002',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    ferm::service { 'swift_container_6001':
        proto   => 'tcp',
        port    => '6001',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    ferm::service { 'swift-rsync':
        proto   => 'tcp',
        port    => '873',
        notrack => true,
        srange  => "(${firewall_rules_str})",
    }

    motd::role { 'role::swift':
        description => 'Openstack Swift Service Accounting and Container',
    }
}
