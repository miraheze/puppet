# == Class: swift::proxy

class swift::proxy (
    Integer              $num_workers   = lookup('swift::proxy::num_workers', {'default_value' => $::processorcount}),
    Hash                 $accounts      = lookup('swift::accounts'),
    Hash                 $accounts_keys = lookup('swift::accounts_keys'),
){

    ensure_packages(['swift-proxy'])

    $swift_password = lookup('mediawiki::swift_password')
    file { '/etc/swift/proxy-server.conf':
        ensure  => present,
        content => template('swift/proxy-server.conf.erb'),
        require => Package['swift-proxy'],
        notify  => Service['swift-proxy'],
    }

    file { '/etc/swift/dispersion.conf':
        owner     => 'swift',
        group     => 'swift',
        mode      => '0440',
        content   => template('swift/dispersion.conf.erb'),
        require   => Package['swift'],
        show_diff => false,
    }

    # Supports bullseye
    file { '/usr/local/lib/python3.9/dist-packages/miraheze/':
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/swift/SwiftMedia/miraheze/',
        recurse => 'remote',
        notify  => Service['swift-proxy'],
    }

    service { 'swift-proxy':
        ensure  => running,
        require => Package['swift-proxy'],
    }

    ssl::wildcard { 'swift wildcard': }

    nginx::site { 'swift':
        ensure => present,
        source => 'puppet:///modules/swift/nginx/swift.conf',
    }

    # TODO: get monotoring working
    #monitoring::services { 'Swift Proxy':
    #    check_command => 'tcp',
    #    vars          => {
    #        tcp_address => $::ipaddress6,
    #        tcp_port    => '8080',
    #    },
    #}
}
