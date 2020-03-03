# class: role::db
class role::db {
    include mariadb::packages

    $mediawiki_password = hiera('passwords::db::mediawiki')
    $wikiadmin_password = hiera('passwords::db::wikiadmin')
    $piwik_password = hiera('passwords::db::piwik')
    $phabricator_password = hiera('passwords::db::phabricator')
    $grafana_password = hiera('passwords::db::grafana')
    $exporter_password = hiera('passwords::db::exporter')
    $internetarchivebot_password = hiera('passwords::db::iabot')
    $icinga_password = hiera('passwords::db::icinga')

    class { 'mariadb::config':
        config      => 'mariadb/config/mw.cnf.erb',
        password    => hiera('passwords::db::root'),
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

    # temp
    ufw::allow { 'mysql port db4 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '81.4.109.166',
    }

    ufw::allow { 'mysql port db5 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '185.52.1.89',
    }



    ufw::allow { 'mysql port lizardfs6':
        proto => 'tcp',
        port  => '3306',
        from  => '54.36.165.161',
    }

    ufw::allow { 'mysql port mw1 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '185.52.1.75',
    }

    ufw::allow { 'mysql port mw1 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2a00:d880:6:786:0000:0000:0000:0002',
    }

    ufw::allow { 'mysql port mw2 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '185.52.2.113',
    }

    ufw::allow { 'mysql port mw2 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2a00:d880:5:799:0000:0000:0000:0002',
    }

    ufw::allow { 'mysql port mw3 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '81.4.121.113',
    }

    ufw::allow { 'mysql port mw3 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2a00:d880:5:b45:0000:0000:0000:0002',
    }

    ufw::allow { 'mysql port misc1 ipv4':
        proto => 'tcp',
        port  => '3306',
        from  => '185.52.1.76',
    }

    ufw::allow { 'mysql port misc1 ipv6':
        proto => 'tcp',
        port  => '3306',
        from  => '2a00:d880:0006:0787:0000:0000:0000:0003',
    }

    ufw::allow { 'mysql port misc2':
        proto => 'tcp',
        port  => '3306',
        from  => '81.4.127.174',
    }

    ufw::allow { 'mysql port misc4':
        proto => 'tcp',
        port  => '3306',
        from  => '185.52.3.121',
    }

    ufw::allow { 'mysql port test1':
        proto => 'tcp',
        port  => '3306',
        from  => '185.52.2.243',
    }

    # new servers
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


    # temp whitelisting for cyberpower
    ufw::allow { 'mysql port cyberpower1':
        proto => 'tcp',
        port  => '3306',
        from  => '208.80.155.163',
    }
    ufw::allow { 'mysql port cyberpower2':
        proto => 'tcp',
        port  => '3306',
        from  => '185.15.56.22',
    }
    ufw::allow { 'mysql port cyberpower3':
        proto => 'tcp',
        port  => '3306',
        from  => '185.15.56.1',
    }
    ufw::allow { 'mysql port cyberpower4':
        proto => 'tcp',
        port  => '3306',
        from  => '208.80.155.131',
    }
    ufw::allow { 'mysql port cyberpower5':
        proto => 'tcp',
        port  => '3306',
        from  => '208.80.155.255',
    }

    # Create a user to allow db transfers between servers
    users::user { 'dbcopy':
        ensure      => present,
        uid         => 3000,
        ssh_keys    => [
		'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAm2zOFC/jMPPX2hbWHfuONDhylWRS6y7XXgGu8txQ6K dbcopy@db4'
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
