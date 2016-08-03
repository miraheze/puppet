# Client class for all backup servers
class bacula::client {
    package { 'bacula-client':
        ensure => present,
    }

    service { 'bacula-fd':
        ensure  => running,
        require => Package['bacula-client'],
    }

    file { ['/bacula', '/bacula/restore']:
        ensure => directory,
        owner  => 'bacula',
    }

    $password = hiera('passwords::bacula::director')

    file { '/etc/bacula/bacula-fd.conf':
        ensure  => present,
        content => template('bacula/client/bacula-fd.conf'),
        notify  => Service['bacula-fd'],
    }

    ufw::allow { 'bacula_9102':
        proto => 'tcp',
        port  => 9102,
    }
}
