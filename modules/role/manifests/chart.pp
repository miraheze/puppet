# role: chart
# copy-pasted from mathoid
class role::chart {
    include chart

    $chart_src_sets = ($facts['networking']['hostname'] =~ /^test.+$/) ? {
        true    => ['BASTION_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'ICINGA2_HOSTS'],
        default => ['BASTION_HOSTS', 'MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'ICINGA2_HOSTS'],
    }

    firewall::service { 'chart':
        proto    => 'tcp',
        port     => 6284,
        src_sets => $chart_src_sets,
        notrack  => true,
    }

    system::role { 'chart':
        description => 'Chart server',
    }
}
