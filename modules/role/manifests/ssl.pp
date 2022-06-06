# role: ssl
class role::ssl {
    include ::ssl

    $firewall_srange = join(
        query_facts('Class[Role::Varnish] or Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

    if !defined(Ferm::Service['http']) {
        ferm::service { 'http':
            proto   => 'tcp',
            port    => '80',
            srange  => "(${firewall_srange})",
            notrack => true,
        }
    }

    if !defined(Ferm::Service['https']) {
        ferm::service { 'https':
            proto   => 'tcp',
            port    => '443',
            srange  => "(${firewall_srange})",
            notrack => true,
        }
    }

    motd::role { 'role::ssl':
        description => 'SSL management server',
    }
}
