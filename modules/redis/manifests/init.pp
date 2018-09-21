# class: redis
class redis (
    Integer$port = 6379,
    String $maxmemory = '512mb',
    String $maxmemory_policy = 'volatile-lfu',
    Integer $maxmemory_samples = 5,
    Boolean $password = false,
) {
    apt::pin { 'debian_stretch_backports_redis':
        priority   => 740,
        originator => 'Debian',
        release    => 'stretch-backports',
        packages   => 'redis-server',
    }

    package { 'redis-server':
        ensure  => present,
        require => Apt::Pin['debian_stretch_backports_redis'],
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

    icinga2::custom::services { 'Redis Process':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_redis',
        },
    }
}
