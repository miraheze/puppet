# Small acme-tiny manifest
class acme {
    git::clone { 'acme-tiny':
        ensure    => present,
        directory => '/root/acme-tiny',
        origin    => 'https://github.com/diafygi/acme-tiny.git',
    }

    file { '/root/ssl-certificate':
        ensure => present,
        source => 'puppet:///modules/acme/ssl-certificate',
        mode   => '0555',
    }

    file { '/root/acme-tiny/account.key':
        ensure => present,
        source => 'puppet:///private/acme/account.key',
    }
}
