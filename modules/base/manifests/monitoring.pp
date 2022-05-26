# base::monitoring
class base::monitoring {
    include prometheus::exporter::node

    $nagios_packages = [ 'monitoring-plugins', 'nagios-nrpe-server', ]
    package { $nagios_packages:
        ensure => present,
    }

    file { '/etc/nagios/nrpe.cfg':
        ensure  => present,
        source  => 'puppet:///modules/base/icinga/nrpe.cfg',
        require => Package['nagios-nrpe-server'],
        notify  => Service['nagios-nrpe-server'],
    }

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

    file { '/usr/lib/nagios/plugins/check_ipmi_sensors':
        ensure => present,
        source => 'puppet:///modules/base/icinga/check_ipmi_sensors',
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
            'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_gdnsd_datacenters',
            'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_puppet_run',
            'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_smart',
            'ALL = NOPASSWD: /usr/sbin/ipmi-sel',
            'ALL = NOPASSWD: /usr/sbin/ipmi-sensors',
        ],
    }

    monitoring::hosts { $::hostname: }

    monitoring::nrpe { 'Disk Space':
        command => '/usr/lib/nagios/plugins/check_disk -w 10% -c 5% -p /',
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#Disk_Space'
    }

    $loadCrit = $facts['virtual_processor_count'] * 2.0
    $loadWarn = $facts['virtual_processor_count'] * 1.7
    monitoring::nrpe { 'Current Load':
        command => "/usr/lib/nagios/plugins/check_load -w ${loadWarn} -c ${loadCrit}",
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#Current_Load'
    }

    monitoring::nrpe { 'Puppet':
        command => '/usr/bin/sudo /usr/lib/nagios/plugins/check_puppet_run -w 3600 -c 43200',
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#Puppet'
    }

    monitoring::services { 'SSH':
        check_command => 'ssh',
        docs          => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#SSH'
    }

    monitoring::nrpe { 'APT':
        command => '/usr/lib/nagios/plugins/check_apt -o',
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#APT'
    }

    monitoring::nrpe { 'NTP time':
        command => '/usr/lib/nagios/plugins/check_ntp_time -H time.cloudflare.com -w 0.1 -c 0.5',
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#NTP'
    }

    # Collect all NRPE command files
    File <| tag == 'nrpe' |>
}
