# class: hhvm
class hhvm {
    include ::apt
    apt::source { 'HHVM apt':
        comment  => 'HHVM apt repo',
        location => 'http://dl.hhvm.com/debian',
        release  => 'jessie',
        repos    => 'main',
        key      => {
            'id'     => '0x5a16e7281be7a449',
            'server' => 'hkp://keyserver.ubuntu.com:80',
        },
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
        require => Apt::Source['HHVM apt'],
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
