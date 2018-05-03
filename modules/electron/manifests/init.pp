# == Class: electron

class electron {

    include nodejs

    require_package(['xvfb', 'libgtk2.0-0', 'ttf-mscorefonts-installer', 'libnotify4' 'libgconf2-4', 'libxss1', 'libnss3', 'dbus-x11'])

    group { 'electron':
        ensure => present,
    }

    user { 'electron':
        ensure     => present,
        gid        => 'electron',
        shell      => '/bin/false',
        home       => '/srv/electron',
        managehome => false,
        system     => true,
    }

    file { '/srv/electron':
        ensure => directory,
    }

    file { '/var/log/electron':
        ensure  => directory,
        owner   => 'electron',
        group   => 'electron',
        require => [User['electron'], Group['electron']],
    }

    exec { 'electron reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/electron.service':
        ensure => present,
        source => 'puppet:///modules/electron/electron.systemd',
        notify => Exec['electron reload systemd'],
    }

    service { 'electron':
        ensure  => running,
        require => File['/etc/systemd/system/electron.service'],
    }

    logrotate::conf { 'electron':
        ensure => present,
        source => 'puppet:///modules/electron/logrotate.conf',
    }
}
