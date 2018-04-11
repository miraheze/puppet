# mediawiki::php7
class mediawiki::php7 {
    $packages = [
        'php-pear',
        'php-mail',
        'php-luasandbox',
        'php7.0',
        'php7.0-curl',
        'php7.0-fpm',
        'php7.0-gd',
        'php7.0-imagick',
        'php7.0-intl',
        'php7.0-json',
        'php7.0-mbstring',
        'php7.0-mcrypt',
        'php7.0-mysql',
        'php7.0-mysqlnd',
        'php7.0-redis',
    ]

    package { $packages:
        ensure => present,
    }

    service { 'php7.0-fpm':
        ensure  => running,
        require => Package['php7.0-fpm'],
    }

    file { '/etc/php/7.0/fpm/php-fpm.conf':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/php/php-fpm-7.0.conf',
        notify => Service['php7.0-fpm'],
    }

    file { '/etc/php/7.0/fpm/pool.d/www.conf':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/php/www-7.0.conf',
        notify => Service['php7.0-fpm'],
    }

    file { '/etc/php/7.0/fpm/php.ini':
        ensure => present,
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/php/php-7.0.ini',
        notify => Service['php7.0-fpm'],
    }
}
