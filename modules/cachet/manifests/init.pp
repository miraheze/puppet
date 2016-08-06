class cachet {
    include ::apache::mod::ssl
    include ::apache::mod::php5

    $database_password = hiera('passwords::db::cachet')
    $redis_password = hiera('passwords::redis::master')
    $cachet_key = hiera('passwords::cachet::key')
    $noreply_password = hiera('passwords::mail::noreply')
    
    apache::site { 'status.miraheze.org':
        ensure => present,
        source => 'puppet:///modules/cachet/apache.conf',
    }

    git::clone { 'cachet':
        ensure    => present,
        directory => '/srv/cachet',
        owner     => 'www-data',
        group     => 'www-data',
        origin    => 'https://github.com/cachethq/Cachet.git',
    }

    exec { 'Cachet composer':
        command     => 'curl -sS https://getcomposer.org/installer | php composer.phar install --no-dev -o',
        cwd         => '/srv/cachet',
        path        => '/usr/bin',
        environment => 'HOME=/srv/cachet',
        user        => 'www-data',
        require     => Git::Clone['cachet'],
    }

    exec { 'php composer.phar require predis/predis':
        cwd         => '/srv/cachet',
        path        => '/usr/bin',
        environment => 'HOME=/srv/cachet',
        user        => 'www-data',
        require     => Exec['Cachet composer'],
    }

   file { '/srv/cachet/.env':
        ensure  => present,
        content => template('cachet/env.erb'),
        require => Git::Clone['cachet'],
    }
}
