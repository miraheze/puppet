# class: parsoid
class parsoid {
    include nodejs

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

    file { '/etc/nginx/sites-enabled/default':
        ensure  => absent,
        require => Package['nginx'],
    }

    nginx::site { 'parsoid':
        ensure  => present,
        source  => 'puppet:///modules/parsoid/nginx/parsoid',
        monitor => false,
    }

    if ! defined(File['/etc/mediawiki']) {
        file { '/etc/mediawiki':
            ensure => directory,
        }
    }

    if ! defined(File['/etc/mediawiki/parsoid']) {
        file { '/etc/mediawiki/parsoid':
            ensure => directory,
        }
    }

    file { '/etc/mediawiki/parsoid/config.yaml':
        ensure  => present,
        content => template('parsoid/config.yaml'),
    }

    file { '/var/log/parsoid':
        ensure  => directory,
        owner   => 'parsoid',
        group   => 'parsoid',
        require => [
            User['parsoid'],
            Group['parsoid']
        ],
    }

    exec { 'parsoid reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/parsoid.service':
        ensure  => present,
        content => template('parsoid/parsoid.systemd.erb'),
        notify  => Exec['parsoid reload systemd'],
    }

    service { 'parsoid':
        ensure    => running,
        require   => File['/etc/systemd/system/parsoid.service'],
        subscribe => File['/etc/mediawiki/parsoid/config.yaml'],
    }

    file { '/etc/rsyslog.d/20-parsoid.conf':
        ensure => present,
        source => 'puppet:///modules/parsoid/parsoid.rsyslog.conf',
        notify => [
            Service['rsyslog'],
            Service['parsoid']
        ],
    }

    logrotate::conf { 'parsoid':
        ensure => present,
        source => 'puppet:///modules/parsoid/logrotate.conf',
    }

    monitoring::services { 'Parsoid':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '8142',
        },
    }
}
