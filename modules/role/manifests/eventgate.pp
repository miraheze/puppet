# === Role eventgate
class role::eventgate {
    include eventgate

    # TODO: Restrict beta access at some point once we get this working.
    firewall::service { 'eventgate':
        proto   => 'tcp',
        port    => 8192,
        src_sets  => ['MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'ICINGA2_HOSTS'],
        notrack => true,
    }

    firewall::service { 'eventgate-prometheus':
        proto   => 'tcp',
        port    => 9102,
        src_sets  => ['PROMETHEUS_HOSTS'],
        notrack => true,
    }

    system::role { 'role::eventgate':
        description => 'EventGate server',
    }
}
