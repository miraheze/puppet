# class: mariadb::packages
class mariadb::packages(
    Enum['11.8'] $version = lookup('mariadb::version', {'default_value' => '11.8'}),
) {
    stdlib::ensure_packages('percona-toolkit')

    $http_proxy = lookup('http_proxy', {'default_value' => undef})
    if $http_proxy and !defined(File['/etc/apt/apt.conf.d/01mariadb']) {
        file { '/etc/apt/apt.conf.d/01mariadb':
            ensure  => present,
            content => template('mariadb/aptproxy.erb'),
        }
    }

    apt::source { 'mariadb_apt':
        comment  => 'MariaDB stable',
        location => "https://mirror.mariadb.org/repo/${version}/debian",
        release  => $facts['os']['distro']['codename'],
        repos    => 'main',
        key      => {
            'name'   => 'mariadb_release_signing_key.pgp',
            'source' => 'puppet:///modules/mariadb/mariadb_release_signing_key.pgp',
        },
    }

    apt::pin { 'mariadb_pin':
        priority => 600,
        origin   => 'mirror.mariadb.org',
        require  => Apt::Source['mariadb_apt'],
        notify   => Exec['apt_update_mariadb'],
    }

    # First installs can trip without this
    exec { 'apt_update_mariadb':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
    }

    stdlib::ensure_packages(
        ['mariadb-server', 'mariadb-backup', 'libjemalloc2'],
        {
            ensure  => present,
            require => Exec['apt_update_mariadb'],
        }
    )

}
