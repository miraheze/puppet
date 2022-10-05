# SPDX-License-Identifier: Apache-2.0
class swift::storage (
    Optional[Integer] $object_server_default_workers = lookup('swift::storage::object_server_default_workers', {'default_value' => undef})
) {
    ensure_packages(['swift-object'])

    class { 'rsync::server':
        log_file => '/var/log/rsyncd.log',
    }

    rsync::server::module { 'object':
        uid             => 'swift',
        gid             => 'swift',
        max_connections => 5,
        path            => '/srv/node/',
        read_only       => 'no',
        lock_file       => '/var/lock/object.lock',
    }

    # set up swift specific configs
    file {
        default:
            owner => 'swift',
            group => 'swift',
            mode  => '0440';
        '/etc/swift/object-server.conf':
            content => template('swift/object-server.conf.erb');
        '/srv/node':
            ensure  => directory,
            require => Package['swift'],
            # the 1 is to allow nagios to read the drives for check_disk
            mode    => '0751',
    }

    service { [
        'swift-object',
        'swift-object-auditor',
        'swift-object-updater',
    ]:
        ensure => running,
    }

    # object-reconstructor and container-sharder are not used in WMF deployment, yet are enabled
    # by the Debian package.
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
        ensure => present,
    }

    file { '/etc/swift/swift-drive-audit.conf':
        owner  => 'root',
        group  => 'root',
        mode   => '0440',
        source => 'puppet:///modules/swift/swift-drive-audit.conf',
    }

    monitoring::services { 'Swift Object Service':
        check_command => 'tcp',
        vars          => {
            tcp_address => $::ipaddress6,
            tcp_port    => '6000',
        },
    }
}
