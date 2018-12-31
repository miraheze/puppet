# == Class: services::parsoid

class services::parsoid {

    include ::services

    group { 'parsoid':
        ensure => present,
    }

    user { 'parsoid':
        ensure     => present,
        gid        => 'parsoid',
        shell      => '/bin/false',
        home       => '/srv/parsoid',
        managehome => false,
        system     => true,
    }

    git::clone { 'parsoid':
        ensure    => present,
        directory => '/srv/parsoid',
        origin    => 'https://github.com/wikimedia/parsoid.git',
        branch    => 'master',
        owner     => 'root',
        group     => 'root',
        mode      => '0755',
    }

    exec { 'parsoid_npm':
        command     => 'sudo -u root npm install',
        creates     => '/srv/parsoid/node_modules',
        cwd         => '/srv/parsoid',
        path        => '/usr/bin',
        environment => 'HOME=/srv/parsoid',
        user        => 'root',
        require     => [
            Git::Clone['parsoid'],
            Package['nodejs']
        ],
    }

    include nginx

    include ssl::wildcard

    $wikis = loadyaml('/etc/puppet/services/services.yaml')

    nginx::site { 'parsoid':
        ensure  => present,
        source  => 'puppet:///modules/services/nginx/parsoid',
        monitor => false,
    }

    file { '/etc/mediawiki/parsoid':
        ensure => directory,
    }

    file { '/etc/mediawiki/parsoid/config.yaml':
        ensure  => present,
        content => template('services/parsoid/config.yaml'),
        require => File['/etc/mediawiki/parsoid'],
        notify  => Service['parsoid'],
    }

    systemd::syslog { 'parsoid':
        readable_by => 'all',
        base_dir    => '/var/log',
        group       => 'root',
        require     => [
            User['parsoid'],
            Group['parsoid'],
        ],
    }

    systemd::service { 'parsoid':
        ensure  => present,
        content => systemd_template('parsoid'),
        restart => true,
        require => Git::Clone['parsoid'],
    }

    monitoring::services { 'parsoid':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '8142',
        },
    }
}
