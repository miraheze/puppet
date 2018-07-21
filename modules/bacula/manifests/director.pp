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

    if hiera('base::monitoring::use_icinga2', false) {
        icinga2::custom::services { 'Bacula Daemon':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_bacula_daemon',
            },
        }

        icinga2::custom::services { 'Bacula Databases db4':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_bacula_databasesdb4',
            },
        }

        icinga2::custom::services { 'Bacula Static Lizardfs1':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_bacula_static_lizardfs1',
            },
        }

        icinga2::custom::services { 'Bacula Static Lizardfs2':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_bacula_static_lizardfs2',
            },
        }

        icinga2::custom::services { 'Bacula Misc4 Lizardfs Master':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_bacula_misc4_lizardfs',
            },
        }

        icinga2::custom::services { 'Bacula Lizardfs1 Lizardfs Chunkserver':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_bacula_lizardfs_lizardfs_chunkserver1',
            },
        }

        icinga2::custom::services { 'Bacula Lizardfs2 Lizardfs Chunkserver':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_bacula_lizardfs2_lizardfs_chunkserver2',
            },
        }

        icinga2::custom::services { 'Bacula Phabricator Static':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_bacula_phab',
            },
        }

        icinga2::custom::services { 'Bacula Private Git':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_bacula_private',
            },
        }
    } else {
        icinga::service { 'bacula_daemon':
            description   => 'Bacula Daemon',
            check_command => 'check_nrpe_1arg!check_bacula_daemon',
        }

        icinga::service { 'bacula_databasesdb4':
            description     => 'Bacula - Databases - db4',
            check_command   => 'check_nrpe_1arg!check_bacula_databasesdb4',
        }

        icinga::service { 'bacula_static_lizardfs1':
            description   => 'Bacula - Static Swift1',
            check_command => 'check_nrpe_1arg!check_bacula_static_lizardfs1',
        }

        icinga::service { 'bacula_static_lizardfs2':
            description   => 'Bacula - Static Lizardfs2',
            check_command => 'check_nrpe_1arg!check_bacula_static_lizardfs2',
        }

        icinga::service { 'bacula_misc4_lizardfs':
            description   => 'Bacula - misc4 Lizardfs master',
            check_command => 'check_nrpe_1arg!check_bacula_misc4_lizardfs',
        }

        icinga::service { 'bacula_lizardfs_lizardfs':
            description   => 'Bacula - lizardfs1 Lizardfs Chunkserver1',
            check_command => 'check_nrpe_1arg!check_bacula_lizardfs1_lizardfs_chunkserver1',
        }

        icinga::service { 'bacula_lizardfs_lizardfs2':
            description   => 'Bacula - lizardfs2 Lizardfs Chunkserver2',
            check_command => 'check_nrpe_1arg!check_bacula_lizardfs2_lizardfs2_chunkserver2',
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

}
