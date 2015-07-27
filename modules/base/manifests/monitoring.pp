# base::monitoring
class base::monitoring {
    $nagios_packages = [ 'nagios-plugins', 'nagios-nrpe-server', ]
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
        ensure => running,
        require => Package['ganglia-monitor'],
        subscribe => File['/etc/ganglia/gmond.conf'],
    }
}
