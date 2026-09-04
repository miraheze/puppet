# role: matomo
class role::matomo {

    include prometheus::exporter::redis
    class { '::redis':
        maxmemory_policy => 'allkeys-lru',
        password         => lookup('passwords::redis::master')
    }
    include ::matomo

    firewall::service { 'http':
        proto    => 'tcp',
        port     => 80,
        src_sets => ['VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
        notrack  => true,
    }

    firewall::service { 'https':
        proto    => 'tcp',
        port     => 443,
        src_sets => ['VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
        notrack  => true,
    }

    system::role { 'matomo':
        description => 'analytics server',
    }
}
