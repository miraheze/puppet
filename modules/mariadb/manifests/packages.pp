# class: mariadb::packages
class mariadb::packages(
    Enum['10.2', '10.3', '10.4'] $version = lookup('mariadb::version', {'default_value' => '10.4'}),
) {

    package { [
        'mydumper',
        'percona-toolkit',
        'sshfs'
    ]:
        ensure => present,
    }

    apt::source { 'mariadb_apt':
        comment     => 'MariaDB stable',
        location    => "http://ams2.mirrors.digitalocean.com/mariadb/repo/${version}/debian",
        release     => "${::lsbdistcodename}",
        repos       => 'main',
        key         => '177F4010FE56CA3336300305F1656F24C74CD1D8',
    }

    apt::pin { 'mariadb_pin':
        priority        => 600,
        origin          => 'ams2.mirrors.digitalocean.com',
        require         => Apt::Source['mariadb_apt'],
        notify          => Exec['apt_update_mariadb'],
    }

    # First installs can trip without this
    exec { 'apt_update_mariadb':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
    }

    package { [
        "mariadb-server-${version}",
        "mariadb-backup"
    ]:
        ensure  => present,
        require => Exec['apt_update_mariadb'],
    }
}
