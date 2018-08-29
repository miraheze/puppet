# class: matomo
class matomo(
    $modules = ['expires', 'rewrite', 'ssl', 'php7'],
    $php_72 = false,
) {
    include ::httpd

    if $php_72 {

        include ::php

        $php_version = '7.2'

        require_package("libapache2-mod-php${php_version}")
    } else {
        $php_version = '7.0'

        require_package('php7.0-curl', 'php7.0-mbstring', 'php7.0-mysql', 'php7.0-gd', 'libapache2-mod-php7.0')
    }

    git::clone { 'matomo':
        directory          => '/srv/matomo',
        origin             => 'https://github.com/matomo-org/matomo',
        branch             => '3.6.0', # Current stable
        recurse_submodules => true,
        owner              => 'www-data',
        group               => 'www-data',
    }

    exec { 'curl -sS https://getcomposer.org/installer | php && php composer.phar install':
        creates     => '/srv/matomo/composer.phar',
        cwd         => '/srv/matomo',
        path        => '/usr/bin',
        environment => 'HOME=/srv/matomo',
        user        => 'www-data',
        require     => Git::Clone['matomo'],
    }

    httpd::site { 'matomo.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/matomo/apache.conf',
        monitor => true,
    }

    file { "/etc/php/${php_version}/apache2/conf.d/20-matomo.ini":
        ensure  => present,
        source  => 'puppet:///modules/matomo/20-matomo.ini',
        notify  => Exec['apache2_test_config_and_restart'],
        require => Package["libapache2-mod-php${php_version}"],
    }

    file_line { 'enable_php_opcache':
        line    => 'opcache.enable=1',
        match   => '^;?opcache.enable\s*\=',
        path    => "/etc/php/${php_version}/apache2/php.ini",
        notify  => Exec['apache2_test_config_and_restart'],
        require => Package["libapache2-mod-php${php_version}"],
    }

    httpd::mod { 'matomo_apache':
        modules => $modules,
        require => Package["libapache2-mod-php${php_version}"],
    }

    $salt = hiera('passwords::matomo::salt')
    $password = hiera('passwords::db::matomo')
    $noreply_password = hiera('passwords::mail::noreply')

    file { '/srv/matomo/config/config.ini.php':
        ensure  => present,
        content => template('matomo/config.ini.php.erb'),
        owner   => 'www-data',
        group   => 'www-data',
        require => Git::Clone['matomo'],
    }
}
