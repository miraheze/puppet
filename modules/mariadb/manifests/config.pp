# class: mariadb::config
class mariadb::config(
    $config                         = undef,
    $password                       = undef,
    $datadir                        = '/srv/mariadb',
    $tmpdir                         = '/tmp',
    $innodb_buffer_pool_instances   = 1,
    $innodb_buffer_pool_size        = '768M',
    $max_connections                = 90,
    $version_102                    = undef,
) {
    file { '/etc/my.cnf':
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template($config),
    }

    file { '/etc/mysql':
        ensure => directory,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
    }

    file { '/etc/mysql/my.cnf':
        ensure  => link,
        target  => '/etc/my.cnf',
        require => File['/etc/mysql'],
    }

    file { $datadir:
        ensure => directory,
        owner  => 'mysql',
        group  => 'mysql',
        mode   => '0755',
    }

    file { $tmpdir:
        ensure => directory,
        owner  => 'mysql',
        group  => 'mysql',
        mode   => '0775',
    }

    file { '/etc/mysql/miraheze':
        ensure => directory,
        owner  => 'mysql',
        group  => 'mysql',
        mode   => '0755',
    }

    file { '/etc/mysql/miraheze/default-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/default-grants.sql.erb'),
    }

    file { '/root/.my.cnf':
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('mariadb/config/root.my.cnf.erb'),
    }

    file { '/var/tmp/mariadb':
        ensure => directory,
        owner  => 'mysql',
        group  => 'mysql',
        mode   => '0644',
    }

    if hiera('base::monitoring::use_icinga2', false) {
        icinga2::custom::services { 'mysql':
            check_command => 'mysql',
            vars          => {
                mysql_hostname => 'host.address',
                mysql_database => 'icinga',
            },
        }
    } else {
        icinga::service { 'mysql':
            description   => 'MySQL',
            check_command => 'check_mysql!icinga',
        }
    }
}
