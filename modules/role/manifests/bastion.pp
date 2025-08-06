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

    $squid_access_hosts_str = join(
        query_facts('', ['networking'])
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

    # Add entire 10.0.0.0/8 (private IP) range and
    # remove individual private IPs.
    $squid_access_hosts_combined = join(
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
        srange => "(${squid_access_hosts_combined})",
    }
}
