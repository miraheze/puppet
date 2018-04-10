# class: parsoid
class parsoid {
    #include apt
    include nginx

    $wikis = loadyaml('/etc/puppet/parsoid/parsoid.yaml')

    # can be redone once we are on mediawiki 1.31
    #apt::source { 'parsoid':
    #    location => 'https://releases.wikimedia.org/debian',
    #    release  => 'jessie-mediawiki',
    #    repos    => 'main',
    #    key      => {
    #        'id'     => 'A6FD76E2A61C5566D196D2C090E9F83F22250DD7',
    #        'server' => 'hkp://keyserver.ubuntu.com:80',
    #    },
    ##}
    
    exec { "install_parsoid":
        command => '/usr/bin/curl -o /opt/parsoid_0.8.0all_all.deb https://people.wikimedia.org/~ssastry/parsoid/debs/parsoid_0.8.0all_all.deb',
        unless  => '/bin/ls /opt/parsoid_0.8.0all_all.deb',
    }

    include ssl::wildcard

    file { '/etc/nginx/sites-enabled/default':
        ensure  => absent,
        require => Package['nginx'],
    }

    file { '/etc/nginx/nginx.conf':
        ensure  => present,
        content => template('parsoid/nginx.conf.erb'),
        require => Package['nginx'],
    }

    nginx::site { 'parsoid':
        ensure  => present,
        source  => 'puppet:///modules/parsoid/nginx/parsoid',
        monitor => false,
    }

    package { "parsoid":
        provider => dpkg,
        ensure   => present,
        source   => '/opt/puppetdb_4.4.0-1~wmf1_all.deb',
        require  => Exec['install_parsoid'],
        # require => Apt::Source['parsoid'],
    }

    service { 'parsoid':
        ensure    => running,
        require   => Package['parsoid'],
        subscribe => File['/etc/mediawiki/parsoid/config.yaml'],
    }

    file { '/etc/mediawiki/parsoid/config.yaml':
        ensure  => present,
        content => template('parsoid/config.yaml'),
    }

    icinga::service { 'parsoid':
        description   => 'Parsoid',
        check_command => 'check_tcp!8142',
    }
}
