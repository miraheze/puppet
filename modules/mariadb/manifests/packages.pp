# class: mariadb::packages
class mariadb::packages(
    Enum['10.2', '10.3'] $version = hiera('mariadb::version', '10.2'),
) {

    package { 'percona-toolkit':
        ensure => present,
    }

    $apt_key = $version ? {
      '10.2' => '177F4010FE56CA3336300305F1656F24C74CD1D8',
      '10.3' => '177F4010FE56CA3336300305F1656F24C74CD1D8',
    }

    apt::source { 'mariadb_apt':
        comment     => 'MariaDB stable',
        location    => "http://ams2.mirrors.digitalocean.com/mariadb/repo/${version}/debian",
        release     => "${::lsbdistcodename}",
        repos       => 'main',
        key         => $apt_key,
    }

    package { "mariadb-server-${version}':
        ensure  => present,
        require => Apt::Source['mariadb_apt'],
    }
}
