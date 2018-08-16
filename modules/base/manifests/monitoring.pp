# base::monitoring
class base::monitoring {
    $nagios_packages = [ 'nagios-plugins', 'nagios-nrpe-server', ]
    package { $nagios_packages:
        ensure => present,
    }

    file { '/etc/nagios/nrpe.cfg':
        ensure  => present,
        content => template('base/icinga/nrpe.cfg.erb'),
        require => Package['nagios-nrpe-server'],
        notify  => Service['nagios-nrpe-server'],
    }

    file { '/usr/lib/nagios/plugins/check_puppet_run':
        ensure => present,
        source => 'puppet:///modules/base/icinga/check_puppet_run',
        mode   => '0555',
    }

    service { 'nagios-nrpe-server':
        ensure     => 'running',
        hasrestart => true,
    }

    ufw::allow { 'prometheus access all hosts':
        proto => 'tcp',
        port  => 9100,
        from  => '81.4.127.174',
    }

    require_package('prometheus-node-exporter')

    service { 'prometheus-node-exporter':
        ensure    => running,
        enable    => true,
        require   => Package['prometheus-node-exporter'],
    }

    # SUDO FOR NRPE
    sudo::user { 'nrpe_sudo':
        user       => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_puppet_run', ],
    }

    if hiera('base::monitoring::use_icinga2', false) {
        icinga2::custom::hosts { $::hostname: }

        icinga2::custom::services { 'Disk Space':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_disk',
            },
        }

        icinga2::custom::services { 'Current Load':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_load',
            },
        }

        icinga2::custom::services { 'Puppet':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_puppet_run',
            },
        }

        icinga2::custom::services { 'SSH':
            check_command => 'ssh',
        }
    } else {
        icinga::host { $::hostname: }

        icinga::service { 'disk_space':
            description   => 'Disk Space',
            check_command => 'check_nrpe_1arg!check_disk',
        }

        icinga::service { 'current_load':
            description   => 'Current Load',
            check_command => 'check_nrpe_1arg!check_load',
        }

        icinga::service { 'puppet':
            description   => 'Puppet',
            check_command => 'check_nrpe_1arg!check_puppet_run',
        }

        icinga::service { 'ssh':
            description   => 'SSH',
            check_command => 'check_ssh',
        }
    }
}
