class role::bastion {
    include squid

    motd::role { 'role::bastion':
        description => 'core access bastion host'
    }

    ferm::service { 'bastion-ssh-public':
        proto => 'tcp',
        port  => '22',
    }

    $squid_access_hosts_str = join(
        query_facts("domain='${domain}'", ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

    ferm::service { 'bastion-squid':
        proto  => 'tcp',
        port   => '8080',
        srange => "(${squid_access_hosts_str})",
    }
}
