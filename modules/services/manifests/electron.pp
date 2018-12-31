# == Class: services::electron
#
# Configures a pdf service using electron.
#
# === Parameters
#
# [*access_key*] A key used to access the pdf.
#
class services::electron (
    String $access_key = 'secret',
) {

    include ::services

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
        owner              => 'electron',
        group              => 'electron',
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
        notify      => Service['electron'],
    }

    systemd::syslog { 'electron':
        readable_by  => 'all',
        base_dir     => '/var/log',
        group        => 'root',
        log_filename => 'electron.log',
        require      => [
            User['electron'],
            Group['electron'],
        ],
    }

    systemd::service { 'electron':
        ensure  => present,
        content => systemd_template('electron'),
        restart => true,
        require => Git::Clone['electron'],
    }

    monitoring::services { 'electron':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '3000',
        },
    }
}
