# class: mariadb::packages
class mariadb::packages(
    $version_102    = undef,
) {

    package { 'percona-toolkit':
        ensure => present,
    }

    if $version_102 {
        apt::source { 'mariadb_apt':
            comment     => 'MariaDB stable',
            location    => 'http://ams2.mirrors.digitalocean.com/mariadb/repo/10.2/debian',
            release     => "${::lsbdistcodename}",
            repos       => 'main',
            key         => '199369E5404BD5FC7D2FE43BCBCB082A1BB943DB',
        }

        package { 'mariadb-server':
            ensure  => present,
            require => Apt::Source['mariadb_apt'],
        }
        
    } else {
        $mariadb_package = [
            'mariadb-client-10.0',
            'mariadb-server-10.0',
            'mariadb-server-core-10.0',
          ]
        }
        package { $mariadb_package:
            ensure  => present,
        }
    }
}
