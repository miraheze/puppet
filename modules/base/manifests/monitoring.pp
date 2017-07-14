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

    package { 'ganglia-monitor':
        ensure => present,
    }

    file { '/etc/ganglia/gmond.conf':
        ensure  => present,
        content => template('base/ganglia/gmond.conf'),
    }

    service { 'ganglia-monitor':
        ensure    => running,
        require   => Package['ganglia-monitor'],
        subscribe => File['/etc/ganglia/gmond.conf'],
    }

    # SUDO FOR NRPE
    sudo::user { 'nrpe_sudo':
        user       => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_puppet_run', ],
    }

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
