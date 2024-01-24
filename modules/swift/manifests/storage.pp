# SPDX-License-Identifier: Apache-2.0
class swift::storage (
    Optional[Integer] $object_server_default_workers = lookup('swift::storage::object_server_default_workers', {'default_value' => undef}),
    Array $swift_devices = lookup('swift::storage::devices')
) {
    stdlib::ensure_packages(['swift-object'])

    systemd::service { 'rsync':
        ensure   => present,
        content  => init_template('rsync', 'systemd_override'),
        override => true,
        restart  => true,
    }

    systemd::service { 'swift-object-replicator':
        ensure   => present,
        content  => init_template('swift-object-replicator', 'systemd_override'),
        override => true,
        restart  => true,
    }

    file { '/etc/rsync.disable.d':
        ensure  => directory,
    }

    file { '/etc/rsync_footer':
        source => 'puppet:///modules/swift/rsync_footer',
        notify => Exec['compile fragments']
    }

    $command = @("COMMAND"/L)
    ls /etc/rsync.d/frag-* 1>/dev/null 2>/dev/null && \
    if [ $? -eq 0 ]; then cat /etc/rsync.d/header /etc/rsync.d/frag-* /etc/rsync_footer > /etc/rsyncd.conf; \
    else cat /etc/rsync.d/header > /etc/rsyncd.conf; fi; $(exit 0) \
    | COMMAND
    class { 'rsync::server':
        log_file       => '/var/log/rsyncd.log',
        custom_command => $command,
        require        => [
            File['/etc/rsync.disable.d'],
            File['/etc/rsync_footer'],
        ],
    }

    $swift_devices.each | $device | {
        rsync::server::module { "object_${device}":
            uid             => 'swift',
            gid             => 'swift',
            max_connections => Integer(length($swift_devices) * 4),
            path            => '/srv/node/',
            read_only       => 'no',
            lock_file       => "/var/lock/object_${device}.lock",
        }
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
        ensure => purged,
    }

    file { '/etc/swift/swift-drive-audit.conf':
        owner  => 'root',
        group  => 'root',
        mode   => '0440',
        source => 'puppet:///modules/swift/swift-drive-audit.conf',
    }

    file { '/usr/local/bin/disable_rsync.py':
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        source => 'puppet:///modules/swift/disable_rsync.py',
    }

    file { '/etc/cron.d/devicecheck':
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/swift/devicecheck.cron',
        require => File['/usr/local/bin/disable_rsync.py'],
    }

    if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens19']['ip']
    } elsif ( $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address = $facts['networking']['ip6']
    }
    monitoring::services { 'Swift Object Service':
        check_command => 'tcp',
        vars          => {
            tcp_address => $address,
            tcp_port    => '6000',
        },
    }
}
