# SPDX-License-Identifier: Apache-2.0
class swift::ac {
    ensure_packages(['swift-account', 'swift-container'])

    class { 'rsync::server':
        log_file => '/var/log/rsyncd.log',
    }

    rsync::server::module { 'account':
        uid             => 'swift',
        gid             => 'swift',
        max_connections => 5 * 2,
        path            => '/srv/node/',
        read_only       => 'no',
        lock_file       => '/var/lock/account.lock',
    }
    rsync::server::module { 'container':
        uid             => 'swift',
        gid             => 'swift',
        max_connections => 5 * 2,
        path            => '/srv/node/',
        read_only       => 'no',
        lock_file       => '/var/lock/container.lock',
    }

    # set up swift specific configs
    file {
        default:
            owner => 'swift',
            group => 'swift',
            mode  => '0440';
        '/etc/swift/account-server.conf':
            content => template('swift/account-server.conf.erb');
        '/etc/swift/container-server.conf':
            content => template('swift/container-server.conf.erb');
        '/etc/swift/container-reconciler.conf':
            content => template('swift/container-reconciler.conf.erb');
        # The uwsgi configurations are similar to what Debian ships but logging to syslog
        '/etc/swift/swift-account-server-uwsgi.ini':
            content => template('swift/swift-account-server-uwsgi.ini.erb');
        '/etc/swift/swift-container-server-uwsgi.ini':
            content => template('swift/swift-container-server-uwsgi.ini.erb');
        '/srv/node':
            ensure  => directory,
            require => Package['swift'],
            # the 1 is to allow nagios to read the drives for check_disk
            mode    => '0751',
    }

    service { [
        'swift-account',
        'swift-account-auditor',
        'swift-account-reaper',
        'swift-account-replicator',
        'swift-container',
        'swift-container-auditor',
        'swift-container-replicator',
        'swift-container-updater',
    ]:
        ensure => running,
    }

    # object-reconstructor and container-sharder are not used.
    # Remove their unit so 'systemctl <action> swift*' exits zero.
    # If one of the units matching the wildcard is masked then systemctl
    # exits non-zero on e.g. restart.
    ['swift-object-reconstructor', 'swift-container-sharder'].each |String $unit| {
        file { "/lib/systemd/system/${unit}.service":
            ensure => absent,
            notify => Exec['reload systemd daemon'],
        }
    }

    exec { 'reload systemd daemon':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    package { 'swift-drive-audit':
        ensure => purged,
    }

    file { '/etc/swift/swift-drive-audit.conf':
        owner  => 'root',
        group  => 'root',
        mode   => '0440',
        source => 'puppet:///modules/swift/swift-drive-audit.conf',
    }

    monitoring::services { 'Swift Account Service':
         check_command => 'tcp',
         vars          => {
             tcp_address => $::ipaddress6,
             tcp_port    => '6002',
         },
     }

    monitoring::services { 'Swift Container Service':
         check_command => 'tcp',
         vars          => {
             tcp_address => $::ipaddress6,
             tcp_port    => '6001',
         },
     }
}
