class role::bastion {
    include base
    include squid

    system::role { 'bastion':
        description => 'core access bastion host'
    }

    ferm::service { 'bastion-ssh-public':
        proto => 'tcp',
        port  => '22',
    }

    $squid_access_hosts_str = vmlib::generate_firewall_ip()

    # Add entire 10.0.0.0/8 (internal network) range and
    # remove individual private IPs.
    $squid_access_hosts_internal = join(
        (
            split($squid_access_hosts_str, ' ')
                .filter |$ip| { $ip !~ /^10\./ } + ['10.0.0.0/8']
        )
        .unique()
        .sort(),
        ' '
    )

    ferm::service { 'bastion-squid':
        proto  => 'tcp',
        port   => '8080',
        srange => "(${squid_access_hosts_internal})",
    }

    ferm::service { 'bastion-ntp':
        proto  => 'udp',
        port   => '123',
        srange => '10.0.0.0/8',
    }
}
