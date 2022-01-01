# base::monitoring
class base::monitoring {
    include ::prometheus::node_exporter

    $nagios_packages = [ 'monitoring-plugins', 'nagios-nrpe-server', ]
    package { $nagios_packages:
        ensure => present,
    }

    $icinga_password = lookup('passwords::db::icinga')
    $nagios_nrpe_listening_address = lookup('nagios_nrpe_listening_address', {'default_value' => '0.0.0.0'})
    file { '/etc/nagios/nrpe.cfg':
        ensure  => present,
        content => template('base/icinga/nrpe.cfg.erb'),
        require => Package['nagios-nrpe-server'],
        notify  => Service['nagios-nrpe-server'],
    }

    $puppetmaster_version = lookup('puppetmaster_version', {'default_value' => 6})
    file { '/usr/lib/nagios/plugins/check_puppet_run':
        ensure  => present,
        content => template('base/icinga/check_puppet_run.erb'),
        mode    => '0555',
    }

    file { '/usr/lib/nagios/plugins/check_smart':
        ensure => present,
        source => 'puppet:///modules/base/icinga/check_smart',
        mode   => '0555',
    }

    service { 'nagios-nrpe-server':
        ensure     => 'running',
        hasrestart => true,
    }

    # SUDO FOR NRPE
    sudo::user { 'nrpe_sudo':
        user       => 'nagios',
        privileges => [
            'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_puppet_run',
            'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_smart',
        ],
    }

    monitoring::hosts { $::hostname: }

    monitoring::services { 'Disk Space':
        check_command   => 'nrpe',
        vars            => {
            nrpe_command    => 'check_disk',
        },
    }

    monitoring::services { 'Current Load':
        check_command   => 'nrpe',
        vars            => {
            nrpe_command    => 'check_load',
        },
    }

    monitoring::services { 'Puppet':
        check_command   => 'nrpe',
        vars            => {
            nrpe_command    => 'check_puppet_run',
        },
    }

    monitoring::services { 'SSH':
        check_command   => 'ssh',
    }

    monitoring::services { 'APT':
        check_command   => 'nrpe',
        vars            => {
            nrpe_command    => 'check_apt',
        },
    }

    monitoring::services { 'NTP time':
        check_command   => 'nrpe',
        vars            => {
            nrpe_command    => 'check_ntp_time',
        },
    }

    if !$facts['is_virtual'] {
        if !empty($facts['disks']['sda']) {
            $type = 'sata'
        } else {
            $type = 'nvme'
        }


        monitoring::services { 'SMART':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => "check_smart_${type}",
            },
        }
    }
}
