# == Class: swift::proxy

class swift::proxy (
    Integer              $num_workers   = lookup('swift::proxy::num_workers', {'default_value' => $facts['processors']['count']}),
    Hash                 $accounts      = lookup('swift::accounts'),
    Hash                 $accounts_keys = lookup('swift::accounts_keys'),
    String               $swift_main_memcached = lookup('swift::proxy::swift_main_memcached', {'default_value' => '[2602:294:0:b23::109]'}),
) {

    stdlib::ensure_packages(['swift-proxy'])

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

    $python_version = $facts['os']['distro']['codename'] ? {
        'bookworm' => 'python3.11',
    }

    file { "/usr/local/lib/${python_version}/dist-packages/wikitide/":
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/swift/SwiftMedia/wikitide/',
        recurse => 'remote',
        notify  => Service['swift-proxy'],
    }

    # stock Debian package uses start-stop-daemon --chuid and init.d script to
    # start swift-proxy, our proxy binds to port 80 so it isn't going to work.
    # Use a modified version of 'swift-proxy' systemd unit
    systemd::service { 'swift-proxy':
        content => systemd_template('swift-proxy'),
    }

    nginx::site { 'swift':
        ensure  => present,
        source  => 'puppet:///modules/swift/nginx/swift.conf',
        monitor => false,
    }

    ssl::wildcard { 'swift wildcard': }

    nginx::site { 'default':
        ensure  => absent,
        monitor => false,
    }

    if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens19']['ip']
    } elsif ( $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address = $facts['networking']['ip6']
    }

    monitoring::services { 'HTTP':
        check_command => 'check_http',
        vars          => {
            address6         => $address,
            http_vhost       => 'swift-lb.wikitide.net',
            http_ignore_body => true,
            # We redirect / in varnish so the 404 is expected in the backend.
            # We don't serve index page.
            http_expect      => 'HTTP/1.1 404',
        },
    }

    monitoring::services { 'HTTPS':
        check_command => 'check_http',
        vars          => {
            address6         => $address,
            http_vhost       => 'swift-lb.wikitide.net',
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
            tcp_address => $address,
            tcp_port    => '80',
        },
    }
}
