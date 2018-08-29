# class: matomo
class matomo {
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
    
    $packages = [
        'php7.2',
        'php7.2-curl',
        'php7.2-fpm',
        'php7.2-gd',
        'php7.2-mbstring',
        'php7.2-mysql',
    ]
    
    require_package($packages)

    service { 'php7.2-fpm':
        ensure  => running,
        require => Package['php7.2-fpm'],
    }

    file { '/etc/php/7.2/fpm/pool.d/www.conf':
        ensure  => 'present',
        mode    => '0755',
        source  => 'puppet:///modules/matomo/www-7.2.conf',
        require => Package['php7.2-fpm'],
        notify  => Service['php7.2-fpm'],
    }

    file { '/etc/php/7.2/fpm/conf.d/20-matomo.ini':
        ensure  => present,
        mode    => '0755',
        source  => 'puppet:///modules/matomo/20-matomo.ini',
        require => Package['php7.2-fpm'],
        notify  => Service['php7.2-fpm'],
    }

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
