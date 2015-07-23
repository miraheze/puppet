# class: piwik
class piwik {
    include ::apache
    include ::apache::mod::expires
    include ::apache::mod::php5

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
        branch    => 'master', # FIXME: shouldn't clone master
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

    file { '/srv/piwik/config/config.ini.php':
        ensure  => present,
        source  => 'puppet:///modules/piwik/config.ini.php',
        require => Git::Clone['piwik'],
    }
}
