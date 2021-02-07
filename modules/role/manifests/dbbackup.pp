# class: role::dbbackup
class role::dbbackup {
    include ssl::wildcard

    $icinga_password = lookup('passwords::db::icinga')

    class { 'mariadb::packages':
    } ->
    file { '/etc/ssl/private':
        ensure  => directory,
        owner   => 'root',
        group   => 'mysql',
        mode    => '0750',
    } ->
    class { 'mariadb::config':
        config          => 'mariadb/config/mw.cnf.erb',
        password        => lookup('passwords::db::root'),
        server_role     => 'slave',
        icinga_password => $icinga_password,
        require         => File['/etc/ssl/private'],
    }

    $clusters = lookup('role::dbbackup::clusters')
    $clusters.map |String $clusterName, Hash[String, Integer]$clusterDetails| {
        mariadb::instance { $clusterName:
            port        => $clusterDetails['port'],
            read_only   => 1,
            require     => Class['mariadb::config'],
        }

        motd::role { "role::dbbackup, cluster ${clusterName}":
            description => "database replica (for backup) of cluster ${clusterName}",
        }
    }

    $fwPort3306 = query_facts("domain='$domain' and (Class[Role::Icinga2])", ['ipaddress', 'ipaddress6'])
    $fwPort3306.each |$key, $value| {
        ufw::allow { "mariadb inbound 3306/tcp for ${value['ipaddress']}":
            proto   => 'tcp',
            port    => 3306,
            from    => $value['ipaddress'],
        }

        ufw::allow { "mariadb inbound 3306/tcp for ${value['ipaddress6']}":
            proto   => 'tcp',
            port    => 3306,
            from    => $value['ipaddress6'],
        }
    }

    # Create a user to allow db transfers between servers
    users::user { 'dbcopy':
        ensure      => present,
        uid         => 3000,
        ssh_keys    => [
            'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFX1yvcRAMqwlbkkhMPhK1GFYrLYM18qC1YUcuUEErxz dbcopy@db6'
        ],
    }
}
