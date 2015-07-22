# class: mariadb::packages
class mariadb::packages {
    package { [
        'mariadb-client-10.0',
        'mariadb-server-10.0',
        'mariadb-server-core-10.0',
        'percona-toolkit',
    ]:
        ensure => present,
    }
}
