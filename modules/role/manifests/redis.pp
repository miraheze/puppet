class role::redis {
    class { '::redis':
        password  => hiera('passwords::redis::master'),
        maxmemory => '512mb',
    }

    ufw::allow { 'redis':
        proto => 'tcp',
        port  => 6379,
    }

    motd::role { 'role::redis':
        description => 'Redis caching server',
    }
}
