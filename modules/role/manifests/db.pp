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

    class { 'mariadb::config':
        config      => 'mariadb/config/mw.cnf.erb',
        password    => hiera('passwords::db::root'),
        server_role => 'master',
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

    ufw::allow { 'mysql port mw1':
        proto => 'tcp',
        port  => '3306',
        from  => '185.52.1.75',
    }

    ufw::allow { 'mysql port mw2':
        proto => 'tcp',
        port  => '3306',
        from  => '185.52.2.113',
    }
	
    ufw::allow { 'mysql port mw3':
        proto => 'tcp',
        port => '3306',
        from => '81.4.121.113',
    }

    ufw::allow { 'mysql port misc1':
        proto => 'tcp',
        port  => '3306',
        from  => '185.52.1.76',
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
    
    ufw::allow { 'mysql port bacula1':
        proto => 'tcp',
        port  => '3306',
        from  => '172.245.38.205',
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
