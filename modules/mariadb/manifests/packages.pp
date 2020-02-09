# class: mariadb::packages
class mariadb::packages(
    Enum['10.2', '10.3', '10.4'] $version = hiera('mariadb::version', '10.2'),
) {

    package { 'percona-toolkit':
        ensure => present,
    }

    apt::source { 'mariadb_apt':
        comment     => 'MariaDB stable',
        location    => "http://ams2.mirrors.digitalocean.com/mariadb/repo/${version}/debian",
        release     => "${::lsbdistcodename}",
        repos       => 'main',
        key         => '177F4010FE56CA3336300305F1656F24C74CD1D8',
        notify      => Exec['apt_update_mariadb'],
    }

    apt::pin { 'mariadb_pin':
        priority        => 600,
        origin          => 'ams2.mirrors.digitalocean.com'
    }

    # First installs can trip without this
    exec {'apt_update_mariadb':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
        require     => Apt::Pin['mariadb_pin'],
    }

    package { "mariadb-server-${version}":
        ensure  => present,
        require => Apt::Source['php_apt'],
    }
}
