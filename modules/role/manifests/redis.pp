# role: redis
class role::redis {
    $redis_heap = lookup('redis::heap', {'default_value' => '7000mb'})
    class { '::redis':
        password  => lookup('passwords::redis::master'),
        maxmemory => $redis_heap,
    }

    $firewall = query_facts("domain='$domain' and (Class[Role::Mediawiki] or Class[Role::Icinga2])", ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "Redis port - ${value['ipaddress']}":
            proto => 'tcp',
            port  => 6379,
            from  => $value['ipaddress'],
        }

        ufw::allow { "Redis port - ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 6379,
            from  => $value['ipaddress6'],
        }
    }

    motd::role { 'role::redis':
        description => 'Redis caching server',
    }
}
