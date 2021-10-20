# role: redis
class role::redis {
    $redis_heap = lookup('redis::heap', {'default_value' => '7000mb'})
    class { '::redis':
        password  => lookup('passwords::redis::master'),
        maxmemory => $redis_heap,
    }

    $firewall_rules = query_facts('Class[Role::Mediawiki] or Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'redis':
        proto  => 'tcp',
        port   => '6379',
        srange => "(${firewall_rules_str})",
    }

    motd::role { 'role::redis':
        description => 'Redis caching server',
    }
}
