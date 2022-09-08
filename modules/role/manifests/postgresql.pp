# role: postgresql
class role::postgresql {

    class { '::postgresql::master':
        root_dir => lookup('postgresql::root_dir', {'default_value' => '/srv/postgres'}),
        use_ssl  => lookup('postgresql::ssl', {'default_value' => false}),
    }

    $firewall_rules = query_facts('Class[Role::Puppetserver]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'postgresql':
        proto   => 'tcp',
        port    => '5432',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    motd::role { 'role::postgresql':
        description => 'hosting postgresql server',
    }
}
