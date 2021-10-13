# class: mariadb::config
class mariadb::config(
    String                       $config                       = undef,
    Optional[Boolean]            $instances                    = undef,
    String                       $password                     = undef,
    String                       $datadir                      = '/srv/mariadb',
    String                       $tmpdir                       = '/tmp',
    Integer                      $innodb_buffer_pool_instances = 1,
    String                       $innodb_buffer_pool_size      = '768M',
    String                       $server_role                  = 'master',
    Integer                      $max_connections              = 90,
    Enum['10.2', '10.3', '10.4'] $version                      = lookup('mariadb::version', {'default_value' => '10.4'}),
    String                       $icinga_password              = undef,
    Integer                      $table_definition_cache       = 10000,
    Integer                      $table_open_cache             = 10000,
) {
    $exporter_password = lookup('passwords::db::exporter')
    $ido_db_user_password = lookup('passwords::icinga_ido')
    $icingaweb2_db_user_password = lookup('passwords::icingaweb2')
    $roundcubemail_password = lookup('passwords::roundcubemail')
    $mariadb_replica_password = lookup('passwords::mariadb_replica_password')

    $server_id = inline_template(
        "<%= @virtual_ip_address.split('.').inject(0)\
{|total,value| (total << 8 ) + value.to_i} %>"
    )

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

    file { '/etc/mysql/debian.cnf':
        owner   => 'mysql',
        group   => 'mysql',
        mode    => '0400',
        require => File['/etc/mysql'],
    }

    file { $datadir:
        ensure  => directory,
        owner   => 'mysql',
        group   => 'mysql',
        mode    => '0755',
        require => Package["mariadb-server-${version}"],
    }

    if $tmpdir != '/tmp' {
        file { $tmpdir:
            ensure  => directory,
            owner   => 'mysql',
            group   => 'mysql',
            mode    => '0775',
            require => Package["mariadb-server-${version}"],
        }
    }

    file { '/etc/mysql/miraheze':
        ensure  => directory,
        owner   => 'mysql',
        group   => 'mysql',
        mode    => '0750',
        require => Package["mariadb-server-${version}"],
    }

    file { '/etc/mysql/miraheze/default-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/default-grants.sql.erb'),
        require => File['/etc/mysql/miraheze'],
    }

    file { '/root/.my.cnf':
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('mariadb/config/root.my.cnf.erb'),
    }

    file { '/var/tmp/mariadb':
        ensure  => directory,
        owner   => 'mysql',
        group   => 'mysql',
        mode    => '0644',
        require => Package["mariadb-server-${version}"],
    }

    systemd::unit { 'mariadb.service':
        ensure   => present,
        content  => template('mariadb/mariadb-systemd-override.conf.erb'),
        override => true,
        restart  => false,
    }

    file { '/usr/lib/nagios/plugins/check_mysql-replication.pl':
         source => 'puppet:///modules/mariadb/check_mysql-replication.pl',
         owner  => 'root',
         group  => 'root',
         mode   => '0755',
     }

    if $instances == undef {
        monitoring::services { 'MariaDB':
            check_command => 'mysql',
            vars          => {
                mysql_hostname  => $::fqdn,
                mysql_username  => 'icinga',
                mysql_password  => $icinga_password,
                mysql_ssl       => true,
                mysql_cacert    => '/etc/ssl/certs/Sectigo.crt',
            },
        }
    }
}
