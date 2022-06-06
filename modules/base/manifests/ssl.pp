# base::ssl
class base::ssl {
    $sslPackages = [
        'openssl',
        'ssl-cert',
        'ca-certificates',
    ]

    package { $sslPackages:
        ensure => present,
    }

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

    file { '/etc/ssl/localcerts':
        ensure  => directory,
        owner   => 'root',
        group   => 'ssl-cert',
        mode    => '0775',
        require => Package['ssl-cert'],
    }
}
