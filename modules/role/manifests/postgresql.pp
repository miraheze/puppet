# role: postgresql
class role::postgresql {
    
    class { '::postgresql::master':
        root_dir => lookup('postgresql::root_dir', {'default_value' => '/srv/postgres'}),
        use_ssl  => lookup('postgresql::ssl', {'default_value' => false}),
    }

    ufw::allow { 'postgresql':
        proto => 'tcp',
        port  => 5432,
    }

    motd::role { 'role::postgresql':
        description => 'hosting postgresql server',
    }
}
