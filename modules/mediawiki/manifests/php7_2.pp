# mediawiki::php7_2
class mediawiki::php7_2 {
    include ::apt

    if !defined(Apt::Source['php72_apt']) {
        apt::source { 'php72_apt':
            comment  => 'PHP 7.2',
            location => 'http://apt.wikimedia.org/wikimedia',
            release  => "${::lsbdistcodename}-wikimedia",
            repos    => 'thirdparty/php72',
            key      => 'B8A2DF05748F9D524A3A2ADE9D392D3FFADF18FB',
            notify   => Exec['apt_update_php'],
        }

        # First installs can trip without this
        exec {'apt_update_php':
            command     => '/usr/bin/apt-get update',
            refreshonly => true,
            logoutput   => true,
        }
    }

    $packages = [
        'php-imagick',
        'php-mcrypt',
        'php-pear',
        'php-mail',
        'php-luasandbox',
        'php-redis',
        'php7.2',
        'php7.2-curl',
        'php7.2-fpm',
        'php7.2-gd',
        'php7.2-intl',
        'php7.2-json',
        'php7.2-mbstring',
        'php7.2-mysql',
        'php7.2-mysqlnd',
    ]

    package { $packages:
        ensure  => present,
        require => Apt::Source['php72_apt'],
    }

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

    file { '/etc/php/7.2/fpm/pool.d/www.conf':
        ensure  => 'present',
        mode    => '0755',
        source  => 'puppet:///modules/mediawiki/php/www-7.2.conf',
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
