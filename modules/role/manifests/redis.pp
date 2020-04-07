# role: redis
class role::redis {
    $redis_heap = lookup('redis::heap', '2900mb')
    class { '::redis':
        password  => lookup('passwords::redis::master'),
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
