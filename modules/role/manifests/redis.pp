class role::redis {
    include private::redis

    class { '::redis':
        password  => hiera('passwords::redis::master),
        maxmemory => '384mb',
    }

    ufw::allow { 'redis':
        proto => 'tcp',
        port  => 6379,
    }

    motd::role { 'role::redis':
        description => 'Redis caching server',
    }
}
