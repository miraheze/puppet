# class: redis
class redis (
    $port = 6379,
    $maxmemory = '512mb',
    $maxmemory_policy = 'volatile-lru',
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

    service { 'redis-server':
        ensure  => running,
        enable  => true,
        require => File['/etc/redis/redis.conf'],
    }

    exec { 'Restart redis if needed':
        command     => '/usr/sbin/service redis-server restart',
        subscribe   => File['/etc/redis/redis.conf'],
        refreshonly => true,
    }

    icinga::service { 'redis':
        description   => 'Redis Process',
        check_command => 'check_nrpe_1arg!check_redis',
    }
}
