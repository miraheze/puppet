# class: piwik
class piwik(
    # use php7 on stretch+
    $modules = ['expires', 'rewrite', 'ssl', 'php5']
) {
    include ::httpd

    if os_version('debian >= stretch') {
        $php_version = '7.0'
        require_package('php7.0-curl', 'php7.0-mysql', 'php7.0-gd', 'libapache2-mod-php7.0')
    } else {
        $php_version = '5'
        require_package('php5-curl', 'php5-mysqlnd', 'php5-gd', 'libapache2-mod-php5')
    }

    git::clone { 'piwik':
        directory          => '/srv/piwik',
        origin             => 'https://github.com/matomo-org/matomo',
        branch             => '3.4.0', # Current stable
        recurse_submodules => true,
        owner              => 'www-data',
        group               => 'www-data',
    }

    exec { 'curl -sS https://getcomposer.org/installer | php && php composer.phar install':
        creates     => '/srv/piwik/composer.phar',
        cwd         => '/srv/piwik',
        path        => '/usr/bin',
        environment => 'HOME=/srv/piwik',
        user        => 'www-data',
        require     => Git::Clone['piwik'],
    }

    httpd::site { 'piwik.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/piwik/apache.conf',
        monitor => true,
    }

    if os_version('debian >= stretch') {
        file { '/etc/php/7.0/apache2/conf.d/20-piwik.ini':
            ensure  => present,
            source  => 'puppet:///modules/piwik/20-piwik.ini',
            notify  => Exec['apache2_test_config_and_restart'],
            require => Package['libapache2-mod-php7.0'],
        }

        file_line { 'enable_php_opcache':
            line    => 'opcache.enable=1',
            match   => '^;?opcache.enable\s*\=',
            path    => '/etc/php/7.0/apache2/php.ini',
            notify  => Exec['apache2_test_config_and_restart'],
            require => Package['libapache2-mod-php7.0'],
        }
    } else {
        file { '/etc/php5/apache2/conf.d/20-piwik.ini':
            ensure  => present,
            source  => 'puppet:///modules/piwik/20-piwik.ini',
            notify  => Exec['apache2_test_config_and_restart'],
            require => Package['libapache2-mod-php5'],
        }

        file_line { 'enable_php_opcache':
            line    => 'opcache.enable=1',
            match   => '^;?opcache.enable\s*\=',
            path    => '/etc/php5/apache2/php.ini',
            notify  => Exec['apache2_test_config_and_restart'],
            require => Package['libapache2-mod-php5'],
        }
    }

    httpd::mod { 'piwik_apache':
        modules => $modules,
        require => Package["libapache2-mod-php${php_version}"],
    }

    $salt = hiera('passwords::piwik::salt')
    $password = hiera('passwords::db::piwik')
    $noreply_password = hiera('passwords::mail::noreply')

    file { '/srv/piwik/config/config.ini.php':
        ensure  => present,
        content => template('piwik/config.ini.php.erb'),
        owner   => 'www-data',
        group   => 'www-data',
        require => Git::Clone['piwik'],
    }
}
