# class: mariadb::packages
class mariadb::packages(
    Enum['10.5', '10.11'] $version = lookup('mariadb::version', {'default_value' => '10.5'}),
) {

    package { [
        'mydumper',
        'percona-toolkit',
    ]:
        ensure => present,
    }

    apt::source { 'mariadb_apt':
        comment  => 'MariaDB stable',
        location => "http://ams2.mirrors.digitalocean.com/mariadb/repo/${version}/debian",
        release  => $facts['os']['distro']['codename'],
        repos    => 'main',
        key      => {
            'name'   => 'mariadb_release_signing_key.pgp',
            'source' => 'https://mariadb.org/mariadb_release_signing_key.pgp',
        },
    }

    apt::pin { 'mariadb_pin':
        priority => 600,
        origin   => 'ams2.mirrors.digitalocean.com',
        require  => Apt::Source['mariadb_apt'],
        notify   => Exec['apt_update_mariadb'],
    }

    # First installs can trip without this
    exec { 'apt_update_mariadb':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
    }

    if $facts['os']['distro']['codename'] == 'bookworm' {
        # It looks like on mariadb 10.11 and above
        # it dosen't contain the version number
        # in the package name.
        $package_name = 'mariadb-server'
    } else {
        $package_name = "mariadb-server-${version}"
    }

    package { [
        $package_name,
        'mariadb-backup',
        'libjemalloc2',
    ]:
        ensure  => present,
        require => Exec['apt_update_mariadb'],
    }
}
