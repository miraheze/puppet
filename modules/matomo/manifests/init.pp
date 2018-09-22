# class: matomo
class matomo {
    git::clone { 'matomo':
        directory          => '/srv/matomo',
        origin             => 'https://github.com/matomo-org/matomo',
        branch             => '3.6.0', # Current stable
        recurse_submodules => true,
        owner              => 'www-data',
        group              => 'www-data',
    }

    exec { 'curl -sS https://getcomposer.org/installer | php && php composer.phar install':
        creates     => '/srv/matomo/composer.phar',
        cwd         => '/srv/matomo',
        path        => '/usr/bin',
        environment => 'HOME=/srv/matomo',
        user        => 'www-data',
        require     => Git::Clone['matomo'],
    }
    
    include ::php

    file { '/etc/php/7.2/fpm/conf.d/20-matomo.ini':
        ensure  => present,
        mode    => '0755',
        source  => 'puppet:///modules/matomo/20-matomo.ini',
        require => Package['php7.2-fpm'],
        notify  => Service['php7.2-fpm'],
    }
    
    include ssl::wildcard

    nginx::site { 'matomo.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/matomo/nginx.conf',
        monitor => true,
    }
    
    $salt = hiera('passwords::piwik::salt')
    $password = hiera('passwords::db::piwik')
    $noreply_password = hiera('passwords::mail::noreply')

    file { '/srv/matomo/config/config.ini.php':
        ensure  => present,
        content => template('matomo/config.ini.php.erb'),
        owner   => 'www-data',
        group   => 'www-data',
        require => Git::Clone['matomo'],
    }
}
