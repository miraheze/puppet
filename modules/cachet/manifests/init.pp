class cachet {
    include ::apache::mod::ssl
    include ::apache::mod::php5

    apache::site { 'cachet.miraheze.org':
        ensure => present,
        source => 'puppet:///modules/cachet/apache.conf',
    }

    file { '/srv/cach':
        ensure => directory,
    }

   git::clone { 'cachet':
        ensure    => present,
        directory => '/srv/cach/cachet',
        origin    => 'https://github.com/cachethq/Cachet.git',
        require   => File['/srv/cach'],
    }

   file { '/srv/cach/cachet/.env':
        ensure  => present,
        content => template('cachet/env.erb'),
    }

}