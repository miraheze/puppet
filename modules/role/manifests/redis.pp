# role: redis
class role::redis {
    $redis_heap = hiera('redis::heap', '2200mb')
    class { '::redis':
        password  => hiera('passwords::redis::master'),
        maxmemory => $redis_heap,
    }

    ufw::allow { 'redis':
        proto => 'tcp',
        port  => 6379,
    }

    motd::role { 'role::redis':
        description => 'Redis caching server',
    }
}
