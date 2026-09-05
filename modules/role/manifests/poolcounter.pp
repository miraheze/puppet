# role: poolcounter
class role::poolcounter {
    include poolcounter

    $poolcounter_src_sets = ($facts['networking']['hostname'] =~ /^test.+$/) ? {
        true    => ['MEDIAWIKI_BETA_HOSTS', 'ICINGA2_HOSTS'],
        default => ['MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'ICINGA2_HOSTS'],
    }

    firewall::service { 'poolcounter':
        proto    => 'tcp',
        port     => 7531,
        src_sets => $poolcounter_src_sets,
        notrack  => true,
    }

    monitoring::nrpe { 'poolcounter process':
        command => '/usr/lib/nagios/plugins/check_procs -c 1:1 -u poolcounter -C poolcounterd',
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#Poolcounter'
    }

    system::role { 'poolcounter':
        description => 'Poolcounter server',
    }
}
