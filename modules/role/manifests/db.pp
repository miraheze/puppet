# class: role::db
class role::db {
    include mariadb::packages

    $mediawiki_password = lookup('passwords::db::mediawiki')
    $wikiadmin_password = lookup('passwords::db::wikiadmin')
    $piwik_password = lookup('passwords::db::piwik')
    $phabricator_password = lookup('passwords::db::phabricator')
    $grafana_password = lookup('passwords::db::grafana')
    $exporter_password = lookup('passwords::db::exporter')
    $icinga_password = lookup('passwords::db::icinga')

    class { 'mariadb::config':
        config      => 'mariadb/config/mw.cnf.erb',
        password    => lookup('passwords::db::root'),
        server_role => 'master',
	icinga_password => $icinga_password,
    }

    file { '/etc/mysql/miraheze/grafana-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/grafana-grants.sql.erb'),
    }

    file { '/etc/mysql/miraheze/mediawiki-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/mediawiki-grants.sql.erb'),
    }

    file { '/etc/mysql/miraheze/piwik-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/piwik-grants.sql.erb'),
    }

    file { '/etc/mysql/miraheze/phabricator-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/phabricator-grants.sql.erb'),
    }

    ufw::allow { 'mysql port db7 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '51.89.160.143',
    }

    ufw::allow { 'mysql port db7 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2001:41d0:800:105a::11',
    }

    ufw::allow { 'mysql port db11 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '51.195.175.114',
    }

    ufw::allow { 'mysql port db11 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2001:41d0:800:170b::2',
    }

    ufw::allow { 'mysql port db12 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '51.195.180.10',
    }

    ufw::allow { 'mysql port db12 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2001:41d0:800:170b::3',
    }

    ufw::allow { 'mysql port db13 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '51.195.180.11',
    }

    ufw::allow { 'mysql port db13 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2001:41d0:800:170b::4',
    }
    ufw::allow { 'mysql port mail1 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '51.89.160.134',
    }

    ufw::allow { 'mysql port mail1 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2001:41d0:800:1056::9',
    }

    ufw::allow { 'mysql port mon1 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '51.89.160.138',
    }

    ufw::allow { 'mysql port mon1 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2001:41d0:800:105a::6',
    }

    ufw::allow { 'mysql port jobrunner1 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '51.89.160.135',
    }

    ufw::allow { 'mysql port jobrunner1 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2001:41d0:800:1056::10',
    }

    ufw::allow { 'mysql port mw4 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '51.89.160.128',
    }

    ufw::allow { 'mysql port mw4 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2001:41d0:800:1056::3',
    }

    ufw::allow { 'mysql port mw5 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '51.89.160.133',
    }

    ufw::allow { 'mysql port mw5 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2001:41d0:800:1056::8',
    }

    ufw::allow { 'mysql port mw6 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '51.89.160.136',
    }

    ufw::allow { 'mysql port mw6 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2001:41d0:800:105a::4',
    }

    ufw::allow { 'mysql port mw7 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '51.89.160.137',
    }

    ufw::allow { 'mysql port mw7 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2001:41d0:800:105a::5',
    }

    ufw::allow { 'mysql port test2 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '51.77.107.211',
    }
 
     ufw::allow { 'mysql port test2 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2001:41d0:800:105a::3',
    }

    ufw::allow { 'mysql port phab1 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '51.89.160.139',
    }

    ufw::allow { 'mysql port phab1 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2001:41d0:800:105a::7',
    }

    # Create a user to allow db transfers between servers
    users::user { 'dbcopy':
        ensure      => present,
        uid         => 3000,
        ssh_keys    => [
		'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFX1yvcRAMqwlbkkhMPhK1GFYrLYM18qC1YUcuUEErxz dbcopy@db6'
        ],
    }

    file { '/etc/ssl/private':
        ensure  => directory,
        owner   => 'root',
        group   => 'mysql',
        mode	=> '0750',
    }

    include ssl::wildcard
    
    motd::role { 'role::db':
        description => 'general database server',
    }
}
