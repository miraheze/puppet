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
}
