# role: postgresql
class role::postgresql {

    class { '::postgresql::master':
        root_dir => lookup('postgresql::root_dir', {'default_value' => '/srv/postgres'}),
        use_ssl  => lookup('postgresql::ssl', {'default_value' => false}),
    }

    firewall::service { 'postgresql':
        proto   => 'tcp',
        port    => 5432,
        src_sets  => ['PUPPETSERVER_HOSTS'],
        notrack => true,
    }

    system::role { 'postgresql':
        description => 'PostgreSQL server',
    }
}
