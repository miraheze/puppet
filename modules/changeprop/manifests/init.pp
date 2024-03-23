# == Class: changeprop

class changeprop (
    $broker_list              = lookup('changeprop::broker_list', {'default_value' => '10.0.18.146:9092'}),
    $jobrunner_host           = lookup('changeprop::jobrunner_host', {'default_value' => 'jobrunner.wikitide.net'}),
    $realm                    = lookup('changeprop::realm', {'default_value' => 'production'}),
    $proxy                    = lookup('changeprop::proxy', {'default_value' => ''}),
    $high_traffic_jobs_config = lookup('changeprop::high_traffic_jobs_config', {'default_value' => {}}),
    $low_traffic_concurrency  = lookup('changeprop::low_traffic_concurrency', {'default_value' => 50}),
    $redis_host               = lookup('changeprop::low_traffic_concurrency', {'default_value' => 'localhost'}),
    $redis_password           = lookup('passwords::redis::master')
) {
    stdlib::ensure_packages(['nodejs', 'libsasl2-dev'])

    group { 'changeprop':
        ensure => present,
    }

    user { 'changeprop':
        ensure     => present,
        gid        => 'changeprop',
        shell      => '/bin/false',
        home       => '/srv/changeprop',
        managehome => false,
        system     => true,
    }

    git::clone { 'changeprop':
        ensure             => present,
        directory          => '/srv/changeprop',
        origin             => 'https://github.com/miraheze/changeprop-deploy',
        branch             => 'master',
        owner              => 'changeprop',
        group              => 'changeprop',
        mode               => '0755',
        recurse_submodules => true,
        require            => [
          User['changeprop'],
          Group['changeprop'],
        ],
    }

    file { '/etc/changeprop':
        ensure  => directory,
    }

    if lookup('changeprop::jobqueue', {'default_value' => false}) {
        file { '/etc/changeprop/config.yaml':
            ensure  => present,
            content => template('changeprop/jobqueue.config.yaml.erb'),
            require => File['/etc/changeprop'],
            notify  => Service['changeprop'],
        }
    } else {
        file { '/etc/changeprop/config.yaml':
            ensure  => present,
            source  => 'puppet:///modules/changeprop/default.config.yaml',
            require => File['/etc/changeprop'],
            notify  => Service['changeprop'],
        }
    }

    systemd::service { 'changeprop':
        ensure  => present,
        content => systemd_template('changeprop'),
        restart => true,
        require => Git::Clone['changeprop'],
    }

    monitoring::services { 'changeprop':
        check_command => 'tcp',
        vars          => {
            tcp_port  => '7200',
        },
    }
}
