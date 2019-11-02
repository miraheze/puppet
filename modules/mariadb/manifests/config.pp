# class: mariadb::config
class mariadb::config(
    String                       $config                       = undef,
    String                       $password                     = undef,
    String                       $datadir                      = '/srv/mariadb',
    String                       $tmpdir                       = '/tmp',
    Integer                      $innodb_buffer_pool_instances = 1,
    String                       $innodb_buffer_pool_size      = '768M',
    String                       $server_role                  = 'master',
    Integer                      $max_connections              = 90,
    Enum['10.2', '10.3', '10.4'] $version                      = hiera('mariadb::version', '10.2'),
    String                       $icinga_password              = undef,
) {
    $exporter_password = hiera('passwords::db::exporter')
    $ido_db_user_password = hiera('passwords::icinga_ido')
    $icingaweb2_db_user_password = hiera('passwords::icingaweb2')
    $roundcubemail_password = hiera('passwords::roundcubemail')

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

    exec { 'mariadb reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/mariadb.service.d/no-timeout-mariadb.conf':
        ensure => present,
        source => 'puppet:///modules/mariadb/no-timeout-mariadb.conf',
        notify => Exec['mariadb reload systemd'],
    }

    monitoring::services { 'MySQL':
        check_command => 'mysql',
        vars          => {
            mysql_username => 'icinga',
            mysql_database => 'icinga',
            mysql_password => $icinga_password,
            mysql_ssl      => true,
        },
    }
}
