# Small acme-tiny manifest
class acme {
    git::clone { 'acme-tiny':
        ensure    => present,
        directory => '/root/acme-tiny',
        origin    => 'https://github.com/diafygi/acme-tiny.git',
    }

    file { '/root/ssl':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0770',
    }

    file { '/root/ssl-certificate':
        ensure => present,
        source => 'puppet:///modules/acme/ssl-certificate',
        mode   => '0555',
    }

    file { '/root/account.key':
        ensure => present,
        source => 'puppet:///private/acme/account.key',
        require => Git::Clone['acme-tiny'],
    }

    file { '/srv/ssl':
        ensure => directory,
        owner  => 'nagiosre',
        group  => 'nagiosre',
        mode   => '0770',
    }

    file { '/var/lib/nagios/ssl-acme':
        ensure => present,
        source => 'puppet:///modules/acme/ssl-acme',
        owner  => 'nagiosre',
        group  => 'nagiosre',
        mode   => '0775',
    }

    file { '/var/lib/nagios/LE.crt':
        ensure => present,
        source => 'puppet:///modules/acme/LE.crt',
        owner  => 'nagiosre',
        group  => 'nagiosre',
    }

    file { '/var/lib/nagios/id_rsa':
        ensure => present,
        source => 'puppet:///private/acme/id_rsa',
        owner  => 'nagiosre',
        group  => 'www-data',
        mode   => '0440',
    }

    sudo::user { 'nrpe_ssl-certificate':
        user       => 'nagiosre',
        privileges => [
            'ALL = NOPASSWD: /root/ssl-certificate',
        ],
    }
}
