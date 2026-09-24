# role: varnish
class role::cache::cache (
    Boolean $restrict_firewall = lookup('role::cache::cache::restrict_firewall', {'default_value' => false}),
) {
    include base
    include role::cache::varnish
    include role::cache::haproxy
    include role::cache::perfs

    if $restrict_firewall {
        firewall::service { 'http':
            proto    => 'tcp',
            port     => 80,
            src_sets => ['CLOUDFLARE_HOSTS', 'MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'ICINGA2_HOSTS'],
            notrack  => true,
        }

        firewall::service { 'https':
            proto    => 'tcp',
            port     => 443,
            src_sets => ['CLOUDFLARE_HOSTS', 'MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'ICINGA2_HOSTS'],
            notrack  => true,
        }
    } else {
        firewall::service { 'http':
            proto   => 'tcp',
            port    => 80,
            notrack => true,
        }

        firewall::service { 'https':
            proto   => 'tcp',
            port    => 443,
            notrack => true,
        }
    }

    firewall::service { 'direct varnish access':
        proto    => 'tcp',
        port     => 81,
        src_sets => ['MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'CACHE_VARNISH_HOSTS'],
        notrack  => true,
    }

    system::role { 'cache':
        description => 'Runs HAProxy for frontend and varnish for caching server',
    }
}
