# role: mathoid
class role::mathoid {
    include mathoid

    $mathoid_src_sets = ($facts['networking']['hostname'] =~ /^test.+$/) ? {
        true    => ['BASTION_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'ICINGA2_HOSTS'],
        default => ['BASTION_HOSTS', 'MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'ICINGA2_HOSTS'],
    }

    firewall::service { 'mathoid':
        proto    => 'tcp',
        port     => 10044,
        src_sets => $mathoid_src_sets,
        notrack  => true,
    }

    system::role { 'mathoid':
        description => 'Mathoid server',
    }
}
