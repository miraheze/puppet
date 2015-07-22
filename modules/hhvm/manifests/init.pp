# class: hhvm
class hhvm {
    exec { 'HHVM apt-key':
        command => '/usr/bin/apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0x5a16e7281be7a449',
    }

    file { '/etc/apt/sources.list.d/hhvm.list':
        content => 'deb http://dl.hhvm.com/debian jessie main',
        require => Exec['HHVM apt-key'],
    }

    $packages = [
        'php5',
        'php5-curl',
        'php5-gd',
        'php5-imagick',
        'php5-intl',
        'php5-mcrypt',
        'php5-json',
        'php5-mysqlnd',
        'php5-redis',
    ]

    package { $packages:
        ensure => present,
    }

    package { 'hhvm':
        ensure  => present,
        require => File['/etc/apt/sources.list.d/hhvm.list'],
    }

    service { 'hhvm':
        ensure => 'running',
    }

    file { '/etc/hhvm/php.ini':
        ensure  => present,
        source  => 'puppet:///modules/hhvm/php.ini',
        require => Package['hhvm'],
        notify  => Service['hhvm'],
    }

    file { '/etc/hhvm/server.ini':
        ensure  => present,
        source  => 'puppet:///modules/hhvm/server.ini',
        require => Package['hhvm'],
        notify  => Service['hhvm'],
    }
}
