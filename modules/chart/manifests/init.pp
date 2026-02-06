# == Class: chart

class chart {
    stdlib::ensure_packages(['nodejs'])

    group { 'chart':
        ensure => present,
    }

    user { 'chart':
        ensure     => present,
        gid        => 'chart',
        shell      => '/bin/false',
        home       => '/srv/chart',
        managehome => false,
        system     => true,
    }

    git::clone { 'chart':
        ensure             => 'latest',
        directory          => '/srv/chart',
        origin             => 'https://github.com/miraheze/chart-deploy.git',
        branch             => 'main',
        owner              => 'chart',
        group              => 'chart',
        mode               => '0755',
        recurse_submodules => true,
        require            => [
            User['chart'],
            Group['chart'],
        ],
    }

    file { '/etc/chart':
        ensure => directory,
    }

    file { '/etc/chart/config.yaml':
        ensure  => present,
        source  => 'puppet:///modules/chart/config.yaml',
        require => File['/etc/chart'],
        notify  => Service['chart'],
    }

    systemd::service { 'chart':
        ensure         => present,
        content        => systemd_template('chart'),
        restart        => true,
        service_params => {
            hasstatus  => true,
            hasrestart => true
        },
        require        => [
            Git::Clone['chart']
        ]
    }

    monitoring::services { 'chart':
        check_command => 'tcp',
        vars          => {
            tcp_port  => '6284',
        },
    }
}
