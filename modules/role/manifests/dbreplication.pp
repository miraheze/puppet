# class: role::dbreplication
class role::dbreplication {
    include mariadb::packages

    class { 'mariadb::config':
        config   => 'mariadb/config/mw.cnf.erb',
        password => hiera('passwords::db::root'),
    }

    ufw::allow { 'mysql port db2':
        proto => 'tcp',
        port  => '3306',
        from  => '81.4.125.112',
    }

    ufw::allow { 'mysql port db4':
        proto => 'tcp',
        port  => '3306',
        from  => '81.4.109.166',
    }

    file { '/etc/ssl/private':
        ensure  => directory,
        owner   => 'root',
        group   => 'mysql',
        mode	=> '0750',
    }

    include ssl::wildcard

    if $::virtual == 'kvm' {
        sysctl::parameters { 'avoid swap usage':
            values  => { 'vm.swappiness' => 1, },
        }
    }
    
    motd::role { 'role::dbreplication':
        description => 'replication backup database server',
    }
}
