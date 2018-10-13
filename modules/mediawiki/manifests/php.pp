# mediawiki::php
class mediawiki::php {
    include ::php

    service { 'php7.2-fpm':
        ensure  => running,
        require => Package['php7.2-fpm'],
    }

    file { '/etc/php/7.2/fpm/php-fpm.conf':
        ensure  => 'present',
        mode    => '0755',
        source  => 'puppet:///modules/mediawiki/php/php-fpm-7.2.conf',
        require => Package['php7.2-fpm'],
        notify  => Service['php7.2-fpm'],
    }

    file { '/etc/php/7.2/fpm/php.ini':
        ensure  => present,
        mode    => '0755',
        source  => 'puppet:///modules/mediawiki/php/php-7.2.ini',
        require => Package['php7.2-fpm'],
        notify  => Service['php7.2-fpm'],
    }
}
