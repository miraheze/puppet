# Director: the bacula server
class bacula::director {
    package { ['bacula-server', 'bacula-client']:
        ensure => present,
    }

    service { 'bacula-director':
        ensure  => running,
        require => Package['bacula-server'],
    }

    service { 'bacula-fd':
        ensure  => running,
        require => Package['bacula-client'],
    }

    service { 'bacula-sd':
        ensure  => running,
        require => Package['bacula-server'],
    }

    $password = hiera('bacula::director::password)

    file { ['/bacula/backup', '/bacula/restore']:
        esnure => directory,
        owner  => 'bacula',
    }

    file { '/etc/bacula/bacula-dir.conf':
        ensure  => present,
        content => template('bacula/director/bacula-dir.conf'),
        notify  => Service['bacula-director'],
    }

    file { '/etc/bacula/bacula-fd.conf':
        ensure  => present,
        content => template('bacula/director/bacula-fd.conf'),
        notify  => Service['bacula-fd'],
    }

    file { '/etc/bacula/bacula-sd.conf':
        ensure  => present,
        content => template('bacula/director/bacula-sd.conf'),
        notify  => Service['bacula-sd'],
    }

    file { '/etc/bacula/bconsole.conf':
        ensure  => present,
        content => template('bacula/director/bconsole.conf'),
        notify  => Service['bacula-director'],
    }

    file { '/etc/bacula/tray-monitor.conf':
        ensure  => present,
        content => template('bacula/director/tray-monitor.conf'),
        notify  => Service['bacula-director'],
    }

    ufw::allow { 'bacula_9101':
        proto => 'tcp',
        port  => 9101,
    }

    ufw::allow { 'bacula_9102':
        proto => 'tcp',
        port  => 9102,
    }

    ufw::allow { 'bacula_9103':
        proto => 'tcp',
        port  => 9103,
    }
}
