# role: redis
class role::redis (
    String $maxmemory = '2000mb',
    Boolean $enable_firewall = true,
) {
    class { '::redis':
        password  => hiera('passwords::redis::master'),
        maxmemory => $maxmemory,
    }

    if $enable_firewall {
        ufw::allow { 'redis':
            proto => 'tcp',
            port  => 6379,
        }
    }

    motd::role { 'role::redis':
        description => 'Redis caching server',
    }
}
