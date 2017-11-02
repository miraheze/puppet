# class: role::db
class role::db {
    include mariadb::packages

    $mediawiki_password = hiera('passwords::db::mediawiki')
    $wikiadmin_password = hiera('passwords::db::wikiadmin')
    $piwik_password = hiera('passwords::db::piwik')
    $phabricator_password = hiera('passwords::db::phabricator')

    class { 'mariadb::config':
        config   => 'mariadb/config/mw.cnf.erb',
        password => hiera('passwords::db::root'),
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

    ufw::allow { 'mysql port test1':
        proto => 'tcp',
        port  => '3306',
        from  => '185.52.2.243',
    }

    ssl::cert { 'wildcard.miraheze.org': }

    motd::role { 'role::db':
        description => 'general database server',
    }
}
