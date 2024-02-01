# base::ssl
class base::ssl {
    stdlib::ensure_packages([
        'openssl',
        'ssl-cert',
        'ca-certificates',
    ])

    file { 'authority certificates':
        path    => '/etc/ssl/certs',
        source  => 'puppet:///ssl/ca/',
        recurse => 'remote',
        require => Package['ca-certificates'],
    }

    exec { 'update-cas':
        command     => '/usr/sbin/update-ca-certificates',
        refreshonly => true,
        require     => File['authority certificates'],
    }
}
