# class mariadb::instance
# Setups additional instances for hosts that hosts more
# than one instance
# * port: Port where to run the instance (required)
# * datadir: datadir mysql config, by default /srv/mariadb.title
# * tmpdir: datadir mysql config, by default /srv/tmp.title
# * socket: socket mysql config, by default /var/run/mysqld/mysqld.title.sock
# * innodb_buffer_pool_size: config of the same name, it controls how much
#   memory the instace uses. By default, or if it is configured as false,
#   it is unconfigured, and it will default to the one on the common
#   config template (or the mysql default, if not configured there). When
#   configured, it must be passed as a string, such as '11G' or '10000000'.
# * read_only: whether to operate in read_only mode (mariadb::config
#   sets read_only mode to 1 for replicas by default!)
# * pid_file: used PID file, by default /var/run/mysqld/mysqld.title.pid
# From https://github.com/wikimedia/puppet/blob/production/modules/mariadb/manifests/instance.pp
# with changes for Miraheze

define mariadb::instance(
    Integer                             $port,
    Optional[String]                    $datadir = "/srv/mariadb.${title}",
    Optional[String]                    $tmpdir  = "/srv/tmp.${title}",
    Optional[String]                    $socket  = "/var/run/mysqld/mysqld.${title}.sock",
    Optional[String]                    $pid_file = "/var/run/mysqld/mysqld.${title}.pid",
    Optional[String]                    $error_log = "/var/log/mysql/mysql-error.${title}.log",
    Optional[Variant[String, Boolean]]  $innodb_buffer_pool_size = false,
    Optional[String]                    $template = 'mariadb/config/instance.cnf.erb',
    Optional[Integer]                   $read_only = 1,
) {
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
        mode   => '0755',
    }

    file { "/etc/mysql/conf.d/${title}.cnf":
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template($template),
    }

    $icinga_password = lookup('passwords::db::icinga')

    monitoring::services { "MariaDB ${title}":
        check_command => 'mysql',
        docs          => 'https://meta.miraheze.org/wiki/Tech:MariaDB',
        vars          => {
            mysql_hostname => $::fqdn,
            mysql_port     => $port,
            mysql_username => 'icinga',
            mysql_password => $icinga_password,
            mysql_ssl      => true,
            mysql_cacert   => '/etc/ssl/certs/Sectigo.crt',
        }
    }

    monitoring::services { "Check MariaDB Replication ${title}":
        check_command => 'nrpe',
        vars          => {
            nrpe_command => "check_mysql_replication_${title}",
        }
    }
}
