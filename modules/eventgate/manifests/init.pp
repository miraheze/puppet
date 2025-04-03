# == Class: eventgate

class eventgate {
    stdlib::ensure_packages(['nodejs', 'libssl-dev'])

    group { 'eventgate':
        ensure => present,
    }

    user { 'eventgate':
        ensure     => present,
        gid        => 'eventgate',
        shell      => '/bin/false',
        home       => '/srv/eventgate',
        managehome => false,
        system     => true,
    }

    git::clone { 'eventgate':
        ensure             => present,
        directory          => '/srv/eventgate',
        origin             => 'https://github.com/miraheze/eventgate-deploy',
        branch             => 'master',
        owner              => 'eventgate',
        group              => 'eventgate',
        mode               => '0755',
        recurse_submodules => true,
        require            => [
          User['eventgate'],
          Group['eventgate'],
        ],
    }

    git::clone { 'jsonschema':
        ensure             => present,
        directory          => '/srv/jsonschema',
        origin             => 'https://gitlab.wikimedia.org/repos/data-engineering/schemas-event-primary.git',
        branch             => 'master',
        owner              => 'eventgate',
        group              => 'eventgate',
        mode               => '0755',
        recurse_submodules => true,
        require            => [
          User['eventgate'],
          Group['eventgate'],
        ],
    }

    file { '/srv/eventgate/eventgate-custom.js':
        ensure  => present,
        source  => 'puppet:///modules/eventgate/eventgate-custom.js',
        require => Git::Clone['eventgate'],
        notify  => Service['eventgate'],
    }

    file { '/srv/eventgate/stream-configs.js':
        ensure  => present,
        source  => 'puppet:///modules/eventgate/stream-configs.js',
        require => Git::Clone['eventgate'],
        notify  => Service['eventgate'],
    }

    file { '/etc/eventgate':
        ensure => directory,
    }

    file { '/etc/eventgate/config.yaml':
        ensure  => present,
        source  => 'puppet:///modules/eventgate/config.yaml',
        require => [
            File['/etc/eventgate'],
            Git::Clone['jsonschema']
        ],
        notify  => Service['eventgate'],
    }

    systemd::service { 'eventgate':
        ensure  => present,
        content => systemd_template('eventgate'),
        restart => true,
        require => Git::Clone['eventgate'],
    }

    monitoring::services { 'eventgate':
        check_command => 'tcp',
        vars          => {
            tcp_port  => '8192',
        },
    }
}
