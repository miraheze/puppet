# role: matomo
class role::matomo {

    include prometheus::exporter::redis
    class { '::redis':
        password => lookup('passwords::redis::master')
    }
    include ::matomo

    $firewall_srange = join(
        query_facts('Class[Role::Varnish] or Class[Role::Icinga2]', ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'http':
        proto   => 'tcp',
        port    => '80',
        srange  => "(${firewall_srange})",
        notrack => true,
    }

    ferm::service { 'https':
        proto   => 'tcp',
        port    => '443',
        srange  => "(${firewall_srange})",
        notrack => true,
    }

    motd::role { 'role::matomo':
        description => 'central analytics server',
    }
}
