class ganglia {
    $packages = [
        'rrdtool',
        'gmetad',
        'ganglia-webfrontend',
    ]

    package { $packages:
        ensure => present,
    }

    file { '/etc/ganglia/gmetad.conf':
        ensure => present,
        source => 'puppet:///modules/ganglia/gmetad.conf',
    }
}
