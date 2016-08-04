class cachet {
    include ::apache::mod::ssl
    include ::apache::mod::php5
    $database_password = hiera('passwords::db::cachet')
    $redis_password = hiera('passwords::redis::master')
    
    apache::site { 'status.miraheze.org':
        ensure => present,
        source => 'puppet:///modules/cachet/apache.conf',
    }

    git::clone { 'cachet':
        ensure    => present,
        directory => '/srv/cachet',
        origin    => 'https://github.com/cachethq/Cachet.git',
    }

    exec { 'Cachet composer':
        command     => 'curl -sS https://getcomposer.org/installer | php && php composer.phar install',
        creates     => '/srv/cachet/composer.phar',
        cwd         => '/srv/cachet',
        path        => '/usr/bin',
        environment => 'HOME=/srv/cachet',
        user        => 'www-data',
        require     => Git::Clone['cachet'],
    }

   file { '/srv/cachet/.env':
        ensure  => present,
        content => template('cachet/env.erb'),
        require => Git::Clone['cachet'],
    }
}
