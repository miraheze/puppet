# role: letsencrypt
class role::letsencrypt {
    include ::letsencrypt

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

    @@sshkey { 'github.com':
        ensure       => present,
        type         => 'ecdsa-sha2-nistp256',
        key          => 'AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=',
        host_aliases => [ 'github.com' ],
    }

    motd::role { 'role::letsencrypt':
        description => 'LetsEncrypt server',
    }
}
