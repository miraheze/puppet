class ganglia {
    $packages = [
        'rrdtool',
        'gmetad',
        'gabglia-webfrontend',
    ]

    package { $packages:
        ensure => present,
    }

    file { '/etc/ganglia/gmetad.conf':
        ensure => present,
        source => 'puppet:///modules/ganglia/gmetad.conf',
    }

    service { 'ganglia-monitor':
        ensure    => running,
        require   => Package['ganglia-monitor'],
        subscribe => File['/etc/ganglia/gmetad.conf'],
    }
}
