# role: varnish
class role::varnish (
    Boolean $restrict_firewall = lookup('role::varnish::restrict_firewall', {'default_value' => false}),
) {
    include ::varnish
    include fail2ban
    include prometheus::exporter::varnishreqs
    include role::cache::perfs

    # Temporarily disabling this due to
    # service keep being restarted on
    # puppet runs.
    # nftables::rules { 'varnish-connlimits':
    #    prio  => 1,
    #    chain => 'input',
    #    rules => [
    #        'tcp dport { 80, 443 } ct count over 80 reject with tcp reset',
    #        'tcp dport { 80, 443 } ct state new limit rate over 120/second counter drop',
    #    ],
    # }

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
        src_sets => ['MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS'],
        notrack  => true,
    }

    system::role { 'varnish':
        description => 'Varnish caching server',
    }
}
