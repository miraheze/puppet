# class: matomo
class matomo {
    include ::apache
    include ::apache::mod::expires
    include ::apache::mod::php5
    include ::apache::mod::rewrite
    include ::apache::mod::ssl

    $packages = [
        'php5-curl',
        'php5-mysqlnd',
        'php5-gd'
    ]

    package { $packages:
        ensure => present,
    }

    git::clone { 'matomo':
        directory => '/srv/matomo',
        origin    => 'https://github.com/matomo-org/matomo',
        branch    => '3.3.0', # Current stable
        recurse_submodules => true,
        owner     => 'www-data',
        group     => 'www-data',
    }

    exec { 'curl -sS https://getcomposer.org/installer | php && php composer.phar install':
        creates     => '/srv/matomo/composer.phar',
        cwd         => '/srv/matomo',
        path        => '/usr/bin',
        environment => 'HOME=/srv/matomo',
        user        => 'www-data',
        require     => Git::Clone['matomo'],
    }

    apache::site { 'matomo.miraheze.org':
        ensure => present,
        source => 'puppet:///modules/matomo/apache.conf',
    }

    file { '/etc/php5/apache2/conf.d/20-matomo.ini':
        ensure => present,
        source => 'puppet:///modules/matomo/20-matomo.ini',
        notify => Exec['apache2_test_config_and_restart'],
    }

    file_line { 'enable_php_opcache':
        line   => 'opcache.enable=1',
        match  => '^;?opcache.enable\s*\=',
        path   => '/etc/php5/apache2/php.ini',
        notify => Exec['apache2_test_config_and_restart'],
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
