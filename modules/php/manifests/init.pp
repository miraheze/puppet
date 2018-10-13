# class: php
class php {
    include ::apt

    if !defined(Apt::Source['php72_apt']) {
        apt::key { 'php72_key':
          id     => 'DF3D585DB8F0EB658690A554AC0E47584A7A714D',
          source => 'https://packages.sury.org/php/apt.gpg',
        }

        apt::source { 'php72_apt':
          location => 'https://packages.sury.org/php/',
          release  => "${::lsbdistcodename}",
          repos    => 'main',
          notify   => Exec['apt_update_php'],
        }

        # First installs can trip without this
        exec {'apt_update_php':
            command     => '/usr/bin/apt-get update',
            refreshonly => true,
            logoutput   => true,
        }
    }

    $php_packages = [
        'php-apcu',
        'php-igbinary',
        'php-imagick',
        'php-luasandbox',
        'php-mail',
        'php-mailparse',
        'php-pear',
        'php-redis',
        'php7.2',
        'php7.2-cli',
        'php7.2-curl',
        'php7.2-dba',
        'php7.2-dev',
        'php7.2-fpm',
        'php7.2-gd',
        'php7.2-gettext',
        'php7.2-intl',
        'php7.2-json',
        'php7.2-mbstring',
        'php7.2-mysql',
        'php7.2-xml',
    ]
    
    require_package($php_packages)

    service { 'php7.2-fpm':
        ensure  => running,
        require => Package['php7.2-fpm'],
    }

    file { '/etc/php/7.2/fpm/pool.d/www.conf':
        ensure  => 'present',
        mode    => '0755',
        source  => 'puppet:///modules/php/www-7.2.conf',
        require => Package['php7.2-fpm'],
        notify  => Service['php7.2-fpm'],
    }
}
