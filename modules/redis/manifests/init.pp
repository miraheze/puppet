# class: redis
class redis (
    Integer$port = 6379,
    String $maxmemory = '512mb',
    String $maxmemory_policy = 'allkeys-lru',
    Integer $maxmemory_samples = 5,
    Variant[Boolean, String] $password = false,
) {

    $jobrunner = lookup('jobrunner', {'default_value' => false})

    package { 'redis-server':
        ensure  => present,
    }

    file { '/etc/redis/redis.conf':
        content => template('redis/redis.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['redis-server'],
        notify  => Service['redis-server'],
    }

    file { '/srv/redis':
        ensure  => directory,
        owner   => 'redis',
        group   => 'redis',
        mode    => '0755',
        require => Package['redis-server'],
    }

    # Disabling transparent hugepages is strongly recommended
    # in http://redis.io/topics/latency.
    sysfs::parameters { 'disable_transparent_hugepages':
        values => { 'kernel/mm/transparent_hugepage/enabled' => 'never' },
    }

    # Background save may fail under low memory condition unless
    # vm.overcommit_memory is 1.
    sysctl::parameters { 'vm.overcommit_memory':
        values => { 'vm.overcommit_memory' => 1 },
    }

    systemd::service { 'redis-server':
        ensure  => present,
        content => systemd_template('redis-server'),
        restart => true,
        require => Package['redis-server'],
    }

    monitoring::services { 'Redis Process':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_redis',
        },
    }
}
