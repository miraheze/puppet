# role: poolcounter
class role::poolcounter {
    include poolcounter

    $firewall = $facts['networking']['hostname'] =~ /^test1.+$/ ? {
        true    => 'Class[Role::Mediawiki_beta] or Class[Role::Icinga2]',
        default => 'Class[Role::Mediawiki] or Class[Role::Mediawiki_task] or Class[Role::Icinga2]',
    }

    $firewall_rules_str = join(
        query_facts($firewall, ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'poolcounter':
        proto   => 'tcp',
        port    => '7531',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    monitoring::nrpe { 'poolcounter process':
        command => '/usr/lib/nagios/plugins/check_procs -c 1:1 -u poolcounter -C poolcounterd',
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#Poolcounter'
    }

    system::role { 'poolcounter':
        description => 'Poolcounter server',
    }
}
