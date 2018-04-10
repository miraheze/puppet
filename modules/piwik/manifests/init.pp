# class: piwik
class piwik {
    include ::httpd

    $packages = [
        'php5-curl',
        'php5-mysqlnd',
        'php5-gd'
    ]

    package { $packages:
        ensure => present,
    }

    require_package('libapache2-mod-php5')

    git::clone { 'piwik':
        directory          => '/srv/piwik',
        origin             => 'https://github.com/matomo-org/matomo',
        branch             => '3.3.0', # Current stable
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
        ensure => present,
        source => 'puppet:///modules/piwik/apache.conf',
    }

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

    httpd::mod { 'icinga_apache':
        modules => ['expires', 'rewrite', 'ssl', 'php5'],
        require => Package['libapache2-mod-php5'],
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
