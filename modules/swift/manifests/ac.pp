# SPDX-License-Identifier: Apache-2.0
class swift::ac {
    stdlib::ensure_packages(['swift-account', 'swift-container'])

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

    $old_swift = $facts['os']['distro']['codename'] ? {
        'bookworm' => false,
        'bullseye' => true,
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

    if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens19']['ip']
    } elsif ( $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address = $facts['networking']['ip6']
    }

    monitoring::services { 'Swift Account Service':
        check_command => 'tcp',
        vars          => {
            tcp_address => $address,
            tcp_port    => '6002',
        },
    }

    monitoring::services { 'Swift Container Service':
        check_command => 'tcp',
        vars          => {
            tcp_address => $address,
            tcp_port    => '6001',
        },
    }

    # Backups
    systemd::timer::job { 'backups-swift-account-container':
        ensure            => present,
        description       => 'Runs backup of swift account container',
        command           => '/usr/local/bin/wikitide-backup backup swift-account-container',
        interval          => {
            start    => 'OnCalendar',
            interval => 'Sun *-*-* 06:00:00',
        },
        logfile_name      => 'swift-account-container-backup.log',
        syslog_identifier => 'swift-account-container-backup',
        user              => 'root',
    }

    monitoring::nrpe { 'Backups Swift Account Container':
        command  => '/usr/lib/nagios/plugins/check_file_age -w 864000 -c 1209600 -f /var/log/swift-account-container-backup/swift-account-container-backup.log',
        docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
        critical => true
    }
}
