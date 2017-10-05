# Director: the bacula server
class bacula::director {
    package { ['bacula-server', 'bacula-client', 'python-pexpect']:
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

    $password = hiera('passwords::bacula::director')

    file { ['/bacula', '/bacula/backup', '/bacula/restore']:
        ensure => directory,
        owner  => 'bacula',
        require => Package['bacula-server'],
    }

    file { '/etc/bacula/bacula-dir.conf':
        ensure  => present,
        content => template('bacula/director/bacula-dir.conf'),
        require => Package['bacula-server'],
        notify  => Service['bacula-director'],
    }

    file { '/etc/bacula/bacula-fd.conf':
        ensure  => present,
        content => template('bacula/director/bacula-fd.conf'),
        require => Package['bacula-server'],
        notify  => Service['bacula-fd'],
    }

    file { '/etc/bacula/bacula-sd.conf':
        ensure  => present,
        content => template('bacula/director/bacula-sd.conf'),
        require => Package['bacula-server'],
        notify  => Service['bacula-sd'],
    }

    file { '/etc/bacula/bconsole.conf':
        ensure  => present,
        content => template('bacula/director/bconsole.conf'),
        require => Package['bacula-server'],
        notify  => Service['bacula-director'],
    }

    file { '/etc/bacula/tray-monitor.conf':
        ensure  => present,
        content => template('bacula/director/tray-monitor.conf'),
        require => Package['bacula-server'],
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

    file { '/usr/lib/nagios/plugins/check_bacula_backups':
        ensure  => present,
        source  => 'puppet:///modules/bacula/check_bacula_backups',
        mode    => '0555',
        require => Package['nagios-plugins'],
    }

    # Bacula secret keys
    sudo::user { 'nrpe_sudo_checkbaculabackups':
        user       => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_bacula_backups' ],
    }

    icinga::service { 'bacula_daemon':
        description   => 'Bacula Daemon',
        check_command => 'check_nrpe_1arg!check_bacula_daemon',
    }

    icinga::service { 'bacula_databasesdb2':
        description   => 'Bacula - Databases - db2',
        check_command => 'check_nrpe_1arg!check_bacula_databasesdb2',
    }

    icinga::service { 'bacula_databasesdb3':
        description   => 'Bacula - Databases - db3',
        check_command => 'check_nrpe_1arg!check_bacula_databasesdb3',
    }

    icinga::service { 'bacula_static':
        description   => 'Bacula - Static',
        check_command => 'check_nrpe_1arg!check_bacula_static',
    }

    icinga::service { 'bacula_phabstatic':
        description   => 'Bacula - Phabricator Static',
        check_command => 'check_nrpe_1arg!check_bacula_phab',
    }

    icinga::service { 'bacula_private':
        description   => 'Bacula - Private Git',
        check_command => 'check_nrpe_1arg!check_bacula_private',
    }

}
