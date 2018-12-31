# == Class: electron

class electron (
    String $access_key = 'secret',
) {

    include nodejs

    require_package(['xvfb', 'libgtk2.0-0', 'libnotify4', 'libgconf2-4', 'libxss1', 'libnss3', 'dbus-x11'])

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

    git::clone { 'electron':
        ensure             => present,
        directory          => '/srv/electron',
        origin             => 'https://github.com/msokk/electron-render-service.git',
        branch             => '1.0.0',
        owner              => 'root',
        group              => 'root',
        mode               => '0755',
        timeout            => '550',
        recurse_submodules => true,
        before             => Service['electron'],
        require            => [
            User['electron'],
            Group['electron']
        ],
    }

    exec { 'electron_npm':
        command     => 'sudo -u root npm install',
        creates     => '/srv/electron/node_modules',
        cwd         => '/srv/electron',
        path        => '/usr/bin',
        environment => 'HOME=/srv/electron',
        user        => 'root',
        before      => Service['electron'],
        require     => [
            Git::Clone['electron'],
            Package['nodejs']
        ],
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

    monitoring::services { 'Electron':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '3000',
        },
    }
}
