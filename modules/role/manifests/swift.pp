# role: swift
class role::swift {

    include ::swift
    include ::swift::ring

    $firewall_rules_swift_str = join(
        query_facts('Class[Role::Swift] or Class[Role::Icinga2] or Class[Role::Prometheus]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

    $proxy = lookup('swift_proxy_enable', {'default_value' => false})
    if $proxy {
        include ::swift::proxy
        include role::memcached

        $firewall_rules_mediawiki_str = join(
            query_facts('Class[Role::Mediawiki]', ['ipaddress', 'ipaddress6'])
            .map |$key, $value| {
                "${value['ipaddress']} ${value['ipaddress6']}"
            }
            .flatten()
            .unique()
            .sort(),
            ' '
        )

        ferm::service { 'http':
            proto   => 'tcp',
            port    => '80',
            srange  => "(${firewall_rules_mediawiki_str})",
            notrack => true,
        }

        ferm::service { 'https':
            proto   => 'tcp',
            port    => '443',
            srange  => "(${firewall_rules_mediawiki_str})",
            notrack => true,
        }

        ferm::service { 'swift_memcache_11211':
            proto   => 'tcp',
            port    => '11211',
            srange  => "(${firewall_rules_swift_str})",
            notrack => true,
        }
    }

    $ac = lookup('swift_ac_enable', {'default_value' => false})
    if $ac {
        include ::swift::ac

        ferm::service { 'swift_account_6002':
            proto   => 'tcp',
            port    => '6002',
            srange  => "(${firewall_rules_swift_str})",
            notrack => true,
        }

        ferm::service { 'swift_container_6001':
            proto   => 'tcp',
            port    => '6001',
            srange  => "(${firewall_rules_swift_str})",
            notrack => true,
        }
    }

    $object = lookup('swift_object_enable', {'default_value' => false})
    if $object {
        include ::swift::storage

        ferm::service { 'swift_object_6000':
            proto   => 'tcp',
            port    => '6000',
            srange  => "(${firewall_rules_swift_str})",
            notrack => true,
        }
    }

    motd::role { 'role::swift':
        description => 'Openstack Swift Service (Accounting, Container, Proxy, Object)',
    }
}
