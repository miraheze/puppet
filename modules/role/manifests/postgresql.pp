# role: postgresql
class role::postgresql {
    
    class { '::postgresql::master':
        root_dir => lookup('postgresql::root_dir', {'default_value' => '/srv/postgres'}),
        use_ssl  => lookup('postgresql::ssl', {'default_value' => false}),
    }

    $firewall = query_facts('Class[Role::Puppetserver]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "postgresql ${value['ipaddress']}":
            proto => 'tcp',
            port  => 5432,
            from  => $value['ipaddress'],
        }

        ufw::allow { "postgresql ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 5432,
            from  => $value['ipaddress6'],
        }
    }

    motd::role { 'role::postgresql':
        description => 'hosting postgresql server',
    }
}
