# class: hhvm
class hhvm {
    include ::apt

    apt::source { 'HHVM_apt':
        comment  => 'HHVM apt repo',
        location => 'http://dl.hhvm.com/debian',
        release  => 'jessie',
        repos    => 'main',
        key      => {
            'id'     => '36AEF64D0207E7EEE352D4875A16E7281BE7A449',
            'server' => 'hkp://keyserver.ubuntu.com:80',
        },
    }

    $packages = [
        'php-pear',
        'php-mail',
        'php5',
        'php5-curl',
        'php5-gd',
        'php5-imagick',
        'php5-intl',
        'php5-json',
        'php5-mcrypt',
        'php5-mysqlnd',
        'php5-redis',
    ]

    package { $packages:
        ensure => present,
    }

    package { 'hhvm':
        ensure  => present,
        require => Apt::Source['HHVM_apt'],
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

    include private::hhvm

    file { '/etc/hhvm/server.ini':
        ensure  => present,
        content => template('hhvm/server.ini.erb'),
        require => Package['hhvm'],
        notify  => Service['hhvm'],
    }
    
    file { '/var/run/hhvm/hhvm.hhbc':
        ensure  => present,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0644',
        before  => Service['hhvm'],
    }
}
