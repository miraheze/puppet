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
    $roundcubemail_password = lookup('passwords::roundcubemail')
    $icingaweb2_db_user_password = lookup('passwords::icingaweb2')
 
    include ssl::wildcard

    file { '/etc/ssl/private':
        ensure  => directory,
        owner   => 'root',
        group   => 'mysql',
        mode    => '0750',
    }

    class { 'mariadb::config':
        config          => 'mariadb/config/mw.cnf.erb',
        password        => lookup('passwords::db::root'),
        server_role     => 'master',
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

    file { '/etc/mysql/miraheze/roundcubemail-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/roundcubemail-grants.sql.erb'),
    }

    file { '/etc/mysql/miraheze/icinga2-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/icinga2-grants.sql.erb'),
    }

    $fwPort3306 = query_facts("domain='$domain' and (Class[Role::Db] or Class[Role::Dbbackup] or Class[Role::Mediawiki] or Class[Role::Icinga2] or Class[Role::Roundcubemail] or Class[Role::Phabricator])", ['ipaddress', 'ipaddress6'])
    $fwPort3306.each |$key, $value| {
        ufw::allow { "mariadb inbound 3306/tcp for ${value['ipaddress']}":
            proto => 'tcp',
            port  => 3306,
            from  => $value['ipaddress'],
        }

        ufw::allow { "mariadb inbound 3306/tcp for ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 3306,
            from  => $value['ipaddress6'],
        }
    }

    # Create a user to allow db transfers between servers
    users::user { 'dbcopy':
        ensure   => present,
        uid      => 3000,
        ssh_keys => [
    		'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFX1yvcRAMqwlbkkhMPhK1GFYrLYM18qC1YUcuUEErxz dbcopy@db6'
        ],
    }

    # Dedicated account for database backup transfers
    users::user { 'dbbackup-user':
        ensure      => present,
        uid         => 3101,
        ssh_keys    => [
            'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILV8ZJLdefzSMcPe1o40Nw6TjXvt17JSpvxhIwZI0YcF'
        ],
    }

    # Will use parameters (soon)
    class { 'dbbackup::dumper': }

    # We only need to rung a single instance of mysqld_exporter,
    # listens on port 9104 by default.
    prometheus::mysqld_exporter::instance { 'main':
        client_socket => '/run/mysqld/mysqld.sock'
    }
    
    motd::role { 'role::db':
        description => 'general database server',
    }
}
