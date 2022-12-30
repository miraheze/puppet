# == Class: swift::proxy

class swift::proxy (
    Integer              $num_workers   = lookup('swift::proxy::num_workers', {'default_value' => $::processorcount}),
    Hash                 $accounts      = lookup('swift::accounts'),
    Hash                 $accounts_keys = lookup('swift::accounts_keys'),
){

    ensure_packages(['swift-proxy'])

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

    # stock Debian package uses start-stop-daemon --chuid and init.d script to
    # start swift-proxy, our proxy binds to port 80 so it isn't going to work.
    # Use a modified version of 'swift-proxy' systemd unit
    systemd::service { 'swift-proxy':
        content => systemd_template('swift-proxy'),
    }

    ssl::wildcard { 'swift wildcard': }

    nginx::site { 'swift':
        ensure  => present,
        source  => 'puppet:///modules/swift/nginx/swift.conf',
        monitor => false,
    }

    nginx::site { 'default':
        ensure  => absent,
        monitor => false,
    }

    monitoring::services { 'HTTP':
        check_command => 'check_http',
        vars          => {
            address6         => $facts['ipaddress6'],
            http_vhost       => 'swift-lb.miraheze.org',
            http_ignore_body => true,
            # We redirect / in varnish so the 404 is expected in the backend.
            # We don't serve index page.
            http_expect      => 'HTTP/1.1 404',
        },
    }

    monitoring::services { 'HTTPS':
        check_command => 'check_http',
        vars          => {
            address6         => $facts['ipaddress6'],
            http_vhost       => 'swift-lb.miraheze.org',
            http_ssl         => true,
            http_ignore_body => true,
            # We redirect / in varnish so the 404 is expected in the backend.
            # We don't serve index page.
            http_expect      => 'HTTP/1.1 404',
        },
    }

    monitoring::services { 'Swift Proxy':
        check_command => 'tcp',
        vars          => {
            tcp_address => $::ipaddress6,
            tcp_port    => '80',
        },
    }
}
