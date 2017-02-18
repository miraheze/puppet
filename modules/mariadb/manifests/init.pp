# class: mariadb
class mariadb {
    include mariadb::config
    include mariadb::packages

    file { '/var/tmp/mariadb':
        ensure  => directory,
        owner   => 'mysql',
        group   => 'mysql',
        mode    => '0644',
    }

    icinga::service { 'mysql':
        description   => 'MySQL',
        check_command => 'check_mysql!icinga',
    }
}
