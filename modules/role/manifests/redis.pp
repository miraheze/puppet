# role: redis
class role::redis {
    include prometheus::exporter::redis

    $redis_heap = lookup('redis::heap', {'default_value' => '7000mb'})
    class { '::redis':
        persist   => false,
        password  => lookup('passwords::redis::master'),
        maxmemory => $redis_heap,
    }

    $redis_src_sets = ($facts['networking']['hostname'] =~ /^test.+$/) ? {
        true    => ['MEDIAWIKI_BETA_HOSTS', 'ICINGA2_HOSTS'],
        default => ['MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'ICINGA2_HOSTS'],
    }

    firewall::service { 'redis':
        proto    => 'tcp',
        port     => 6379,
        src_sets => $redis_src_sets,
        notrack  => true,
    }

    system::role { 'redis':
        description => 'Redis caching server',
    }
}
