# class: parsoid
class parsoid {
    include apt
    include nginx

    $wikis = loadyaml('/etc/puppet/services/config.yaml')

    apt::source { 'parsoid':
        location => 'https://releases.wikimedia.org/debian',
        release  => 'jessie-mediawiki',
        repos    => 'main',
        key      => {
            'id'     => 'A6FD76E2A61C5566D196D2C090E9F83F22250DD7',
            'server' => 'hkp://keyserver.ubuntu.com:80',
        },
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

    package { 'parsoid':
        ensure  => present,
        require => Apt::Source['parsoid'],
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

    if hiera('base::monitoring::use_icinga2', false) {
        icinga2::custom::services { 'Parsoid':
            check_command => 'tcp',
            vars          => {
                tcp_port    => '8142',
            },
        }
    } else {
        icinga::service { 'parsoid':
            description   => 'Parsoid',
            check_command => 'check_tcp!8142',
        }
    }
}
