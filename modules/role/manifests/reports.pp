# role: reports
class role::reports {
    include reports

    firewall::service { 'http':
        proto    => 'tcp',
        port     => 80,
        src_sets => ['CLOUDFLARE_HOSTS', 'VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
        notrack  => true,
    }

    firewall::service { 'https':
        proto    => 'tcp',
        port     => 443,
        src_sets => ['CLOUDFLARE_HOSTS', 'VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
        notrack  => true,
    }

    system::role { 'reports':
        description => 'TSPortal-hosting server',
    }
}
