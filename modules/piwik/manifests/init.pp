# class: piwik
class piwik {
    include ::apache
    include ::apache::mod::expires
    include ::apache::mod::php5
    include ::apache::mod::rewrite
    include ::apache::mod::ssl
    include private::mariadb
    include private::piwik

    $packages = [
        'php5-curl',
        'php5-mysqlnd',
        'php5-gd'
    ]

    package { $packages:
        ensure => present,
    }
        
    git::clone { 'piwik':
        directory => '/srv/piwik',
        origin    => 'https://github.com/piwik/piwik.git',
        branch    => '2.16.1', # Current stable
        owner     => 'www-data',
        group     => 'www-data',
    }

    exec { "curl -sS https://getcomposer.org/installer | php && php composer.phar install":
        creates => '/srv/piwik/composer.phar',
        cwd     => '/srv/piwik',
        path    => '/usr/bin',
        user    => 'www-data',
    }

    apache::site { 'piwik.miraheze.org':
        ensure => present,
        source => 'puppet:///modules/piwik/apache.conf',
    }

    file { '/etc/php5/apache2/conf.d/20-piwik.ini':
        ensure => present,
        source => 'puppet:///modules/piwik/20-piwik.ini',
        notify => Exec['apache2_test_config_and_restart'],
    }

    file_line { 'enable_php_opcache':
        line   => 'opcache.enable=1',
        match  => '^;?opcache.enable\s*\=',
        path   => '/etc/php5/apache2/php.ini',
        notify => Exec['apache2_test_config_and_restart'],
    }

    file { '/srv/piwik/config/config.ini.php':
        ensure  => present,
        content => template('piwik/config.ini.php.erb'),
        owner   => 'www-data',
        group   => 'www-data',
        require => Git::Clone['piwik'],
    }
}
