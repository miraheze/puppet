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
        'php-mailparse',
        'php7.2-cli',
        'php7.2-curl',
        'php7.2-dev',
        'php7.2-fpm',
        'php7.2-gd',
        'php7.2-gettext',
        'php7.2-json',
        'php7.2-mbstring',
        'php7.2-mysql',
        'php7.2-xml',
    ]
    
    require_package($php_packages)
}
