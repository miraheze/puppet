# == Class: swift::proxy

class swift::proxy {

    require_package(['swift-proxy', 'memcached'])

    $user_accounts = hiera('swift_accounts', [])

    file { '/etc/swift/proxy-server.conf':
        ensure  => present,
        content => template('swift/proxy-server.conf.erb'),
        require => Package['swift-proxy'],
        notify  => Service['swift-proxy'],
    }

    file { '/usr/local/lib/python2.7/dist-packages/miraheze/':
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/swift/SwiftMedia/miraheze/',
        recurse => 'remote',
        notify  => Service['swift-proxy'],
    }

    file { '/usr/local/lib/python2.7/dist-packages/defaulter/':
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/swift/SwiftMedia/defaulter/',
        recurse => 'remote',
        notify  => Service['swift-proxy'],
    }

    service { 'swift-proxy':
        ensure  => running,
        require => Package['swift-proxy'],
    }

    service { 'memcached':
        ensure  => running,
        require => Package['memcached'],
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
