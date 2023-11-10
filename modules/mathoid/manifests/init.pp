# == Class: services::mathoid

class mathoid {
    stdlib::ensure_packages(['librsvg2-dev', 'g++'])

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

    git::clone { 'mathoid':
        ensure             => 'latest',
        directory          => '/srv/mathoid',
        origin             => 'https://github.com/miraheze/mathoid-deploy.git',
        branch             => 'master',
        owner              => 'mathoid',
        group              => 'mathoid',
        mode               => '0755',
        recurse_submodules => true,
        require            => [
          Package['librsvg2-dev'],
          User['mathoid'],
          Group['mathoid']
        ],
    }

    file { '/etc/mathoid':
        ensure  => directory,
        require => File['/etc/mediawiki'],
    }

    file { '/etc/mathoid/config.yaml':
        ensure  => present,
        source  => 'puppet:///modules/mathoid/mathoid_config.yaml',
        require => File['/etc/mathoid'],
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
