# role: postgresql
class role::postgresql {
    
    class { '::postgresql::master':
        root_dir => hiera('postgresql::root_dir', '/srv/postgres'),
        use_ssl  => hiera('postgresql::ssl', false),
    }

    ufw::allow { 'postgresql':
        proto => 'tcp',
        port  => 5432,
    }

    motd::role { 'role::postgresql':
        description => 'hosting postgresql server',
    }
}
