# == Class: swift::proxy

class swift::proxy {
    include nginx

    include ssl::wildcard

    nginx::site { 'swift':
        ensure  => present,
        source  => 'puppet:///modules/swift/nginx/swift',
        monitor => false,
    }

    require_package(['swift-proxy', 'memcached'])

    $user_accounts = hiera('swift_accounts', [])

    file { '/etc/swift/proxy-server.conf':
        ensure  => present,
        content => template('restbase/proxy-server.conf.erb'),
        require => Package['swift-proxy'],
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
