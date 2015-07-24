class role::db {
    include mariadb::packages
    include private::mariadb

    class { 'mariadb::config':
        config   => 'mariadb/config/mw.cnf.erb',
        password => $root_password,
    }

    file { '/etc/mysql/miraheze/mediawiki-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/mediawiki-grants.sql.erb'),
    }

    file { '/etc/mysql/miraheze/piwik-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/piwik-grants.sql.erb'),
    }

    ufw::allow { 'mysql port':
        proto => 'tcp',
        port  => '3306',
        from  => '185.52.1.75',
    }

    ufw::allow { 'mysql port':
        proto => 'tcp',
        port  => '3306',
        from  => '185.52.1.76',
    }

    motd::role { 'role::db':
        description => 'general database server',
    }
}
