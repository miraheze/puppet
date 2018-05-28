# class: redis
class redis (
    $port = 6379,
    $maxmemory = '512mb',
    $maxmemory_policy = 'volatile-lfu',
    $maxmemory_samples = 5,
    $password = false,
) {
    package { 'redis-server':
        ensure => present,
    }

    file { '/etc/redis/redis.conf':
        content => template('redis/redis.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['redis-server'],
    }

    file { '/srv/redis':
        ensure  => directory,
        owner   => 'redis',
        group   => 'redis',
        mode    => '0755',
        require => Package['redis-server'],
    }

    exec { 'redis reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/lib/systemd/system/redis-server.service':
        ensure  => present,
        source  => 'puppet:///modules/redis/redis-server.systemd',
        notify  => Exec['redis reload systemd'],
    }

    service { 'redis-server':
        ensure  => running,
        enable  => true,
        require => File['/lib/systemd/system/redis-server.service'],
    }

    exec { 'Restart redis if needed':
        command     => '/usr/sbin/service redis-server restart',
        subscribe   => File['/etc/redis/redis.conf'],
        refreshonly => true,
    }

    if hiera('base::monitoring::use_icinga2', false) {
        icinga2::custom::services { 'Redis Process':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_redis',
            },
        }
    } else {
        icinga::service { 'redis':
            description   => 'Redis Process',
            check_command => 'check_nrpe_1arg!check_redis',
        }
    }
}
