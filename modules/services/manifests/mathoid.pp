# == Class: services::mathoid

class services::mathoid {

    include ::services

    require_package(['librsvg2-dev', 'g++'])

    group { 'mathoid':
        ensure => present,
    }

    user { 'mathoid':
        ensure     => present,
        gid        => 'mathoid',
        shell      => '/bin/false',
        home       => '/srv/mathoid',
        managehome => false,
        system     => true,
    }

    git::clone { 'mathoid_deploy':
        ensure             => present,
        directory          => '/srv/mathoid',
        origin             => 'https://github.com/wikimedia/mathoid.git',
        branch             => 'master',
        owner              => 'mathoid',
        group              => 'mathoid',
        mode               => '0755',
        timeout            => '550',
        recurse_submodules => true,
        require            => [
            User['mathoid'],
            Group['mathoid']
        ],
    }

    exec { 'mathoid_npm':
        command     => 'npm install --cache /tmp/npm_cache_mathoid',
        creates     => '/srv/mathoid/node_modules',
        cwd         => '/srv/mathoid',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mathoid',
        user        => 'mathoid',
        require     => [
            Git::Clone['mathoid'],
            Package['nodejs']
        ],
    }

    include ssl::wildcard

    nginx::site { 'mathoid':
        ensure  => present,
        source  => 'puppet:///modules/services/nginx/mathoid',
        monitor => false,
    }

    file { '/etc/mediawiki/mathoid':
        ensure  => directory,
        require => File['/etc/mediawiki'],
    }

    file { '/etc/mediawiki/mathoid/config.yaml':
        ensure  => present,
        source  => 'puppet:///modules/services/mathoid/config.yaml',
        require => File['/etc/mediawiki/mathoid'],
        notify  => Service['mathoid'],
    }

    systemd::service { 'mathoid':
        ensure  => present,
        content => systemd_template('mathoid'),
        restart => true,
        require => Git::Clone['mathoid'],
    }

    monitoring::services { 'mathoid':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '10044',
        },
    }
}
