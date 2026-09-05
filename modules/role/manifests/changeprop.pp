# === Role changeprop
class role::changeprop {
    include changeprop
    include role::prometheus::statsd_exporter

    # TODO: Restrict beta access at some point once we get working.
    firewall::service { 'changeprop':
        proto    => 'tcp',
        port     => 7200,
        src_sets => ['MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'ICINGA2_HOSTS'],
        notrack  => true,
    }

    system::role { 'role::changeprop':
        description => 'ChangeProp server',
    }
}
