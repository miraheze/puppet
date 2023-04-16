# == Class: swift

class swift {

    sysctl::parameters { 'swift_performance':
        values => {
            'net.ipv4.tcp_syncookies'      => '0',
            # Disable TIME_WAIT
            'net.ipv4.tcp_tw_reuse'        => '1',

            # Other general network/TCP tuning

            # Increase the number of ephemeral ports
            'net.ipv4.ip_local_port_range' => [ 1024, 65535 ],

            # Recommended to increase this for 1000 BT or higher
            'net.core.netdev_max_backlog'  => 30000,

            # Increase the queue size of new TCP connections
            'net.core.somaxconn'           => 4096,
            'net.ipv4.tcp_max_syn_backlog' => 262144,
            'net.ipv4.tcp_max_tw_buckets'  => 360000,

            # Decrease FD usage
            'net.ipv4.tcp_fin_timeout'     => 3,
            'net.ipv4.tcp_max_orphans'     => 262144,
            'net.ipv4.tcp_synack_retries'  => 2,
            'net.ipv4.tcp_syn_retries'     => 2,
        },
    }

    ensure_packages(['swift', 'python3-swift', 'python3-swiftclient'])

    $hash_path_suffix = lookup('swift_hash_path_suffix')

    ensure_packages(['python3-statsd'])

    file {
        default:
            owner   => 'swift',
            group   => 'swift',
            mode    => '0440',
            require => Package['swift'];
        '/etc/swift':
            ensure  => directory,
            recurse => true;
        '/etc/swift/swift.conf':
            ensure  => file,
            content => template('swift/swift.conf.erb');
        '/var/cache/swift':
            ensure => directory,
            mode   => '0755';
        # Create swift user home.
        '/var/lib/swift':
            ensure => directory,
            mode   => '0755',
    }

    file { '/var/log/swift':
        ensure  => directory,
        owner   => 'swift',
        group   => 'swift',
        require => Package['swift'],
    }

    $swift_password = lookup('mediawiki::swift_password')
    file { '/etc/swift-env.sh':
        ensure  => 'present',
        content => template('swift/swift-env.sh.erb'),
        mode    => '0755',
    }

    logrotate::conf { 'swift':
        ensure => present,
        source => 'puppet:///modules/swift/swift.logrotate.conf',
    }

    rsyslog::conf { 'swift':
        source   => 'puppet:///modules/swift/swift.rsyslog.conf',
        priority => 40,
        require  => File['/var/log/swift'],
    }
}
