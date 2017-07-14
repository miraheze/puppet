# mediawiki::php
class mediawiki::php {
    $packages = [
        'php-pear',
        'php-mail',
        'php5',
        'php5-curl',
        'php5-fpm',
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

    service { 'php5-fpm':
        ensure  => running,
        require => Package['php5-fpm'],
    }

    file { '/etc/php5/fpm/php-fpm.conf':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/php/php-fpm.conf',
        notify => Service['php5-fpm'],
    }

    file { '/etc/php5/fpm/pool.d/www.conf':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/php/www.conf',
        notify => Service['php5-fpm'],
    }

    file { '/etc/php5/fpm/php.ini':
        ensure => present,
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/php/php.ini',
        notify => Service['php5-fpm'],
    }
}
