# == Class: swift::backend

class swift::backend {

    require_package(['swift-account', 'swift-container', 'swift-object'])

    class { 'rsync::server':
        log_file => '/var/log/rsyncd.log',
    }

    rsync::server::module { 'account':
        uid             => 'swift',
        gid             => 'swift',
        max_connections => '5',
        path            => '/srv/node/',
        read_only       => 'no',
        lock_file       => '/var/lock/account.lock',
    }

    rsync::server::module { 'container':
        uid             => 'swift',
        gid             => 'swift',
        max_connections => '5',
        path            => '/srv/node/',
        read_only       => 'no',
        lock_file       => '/var/lock/container.lock',
    }

    file { '/etc/swift/account-server.conf':
        ensure  => present,
        content => template('swift/account-server.conf.erb'),
        require => Package['swift-account'],
        notify  => Service['swift-account'],
    }

    file { '/etc/swift/container-server.conf':
        ensure  => present,
        content => template('swift/container-server.conf.erb'),
        require => Package['swift-container'],
        notify  => Service['swift-container'],
    }

    file { '/etc/swift/object-server.conf':
        ensure  => present,
        content => template('swift/object-server.conf.erb'),
        require => Package['swift-object'],
        notify  => Service['swift-object'],
    }

    service { 'swift-account':
        ensure  => running,
        require => Package['swift-account'],
    }

    service { 'swift-container':
        ensure  => running,
        require => Package['swift-container'],
    }

    service { 'swift-object':
        ensure  => running,
        require => Package['swift-object'],
    }

    # TODO: get monotoring working
    #if hiera('base::monitoring::use_icinga2', false) {
    #    icinga2::custom::services { 'Swift Proxy':
    #        check_command => 'tcp',
    #        vars          => {
    #            tcp_port    => '8080',
    #        },
    #    }
    #} else {
    #    icinga::service { 'swift_proxy':
    #        description   => 'Swift Proxy',
    #        check_command => 'check_tcp!8080',
    #    }
    #}
}
