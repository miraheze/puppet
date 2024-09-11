# role: redis
class role::redis {
    include prometheus::exporter::redis

    if lookup('mediawiki::jobqueue::runner::beta') {
        $redispassword = lookup('passwords::beta::redis::master') 
    } else {
        $redispassword = lookup('passwords::redis::master')
    }

    $redis_heap = lookup('redis::heap', {'default_value' => '7000mb'})
    class { '::redis':
        persist   => false,
        password  => $redispassword,
        maxmemory => $redis_heap,
    }

    $firewall_rules_str = join(
        query_facts('(Class[Role::Mediawiki] and !facts['mediawiki::jobqueue::runner::beta']) or Class[Role::Icinga2]', ['networking'])
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
    ferm::service { 'redis':
        proto   => 'tcp',
        port    => '6379',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    system::role { 'redis':
        description => 'Redis caching server',
    }
}
