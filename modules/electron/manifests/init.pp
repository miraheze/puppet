# == Class: electron

class electron (
    $access_key = 'secret',
) {

    include nodejs

    require_package(['xvfb', 'libgtk2.0-0', 'libnotify4', 'libgconf2-4', 'libxss1', 'libnss3', 'dbus-x11'])

    file { '/srv/electron':
        ensure => directory,
    }

    file { '/var/log/electron':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
    }

    exec { 'electron reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/electron.service':
        ensure  => present,
        content => template('electron/electron.systemd.erb'),
        notify  => Exec['electron reload systemd'],
    }

    service { 'electron':
        ensure  => running,
        require => File['/etc/systemd/system/electron.service'],
    }

    logrotate::conf { 'electron':
        ensure => present,
        source => 'puppet:///modules/electron/logrotate.conf',
    }

    if hiera('base::monitoring::use_icinga2', false) {
        icinga2::custom::services { 'Electron':
            check_command => 'tcp',
            vars          => {
                tcp_port    => '3000',
            },
        }
    } else {
        icinga::service { 'electron':
            description   => 'Electron',
            check_command => 'check_tcp!3000',
        }
    }
}
