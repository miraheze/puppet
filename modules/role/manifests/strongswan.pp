class role::strongswan (
    Optional[Any] $hosts = undef
) {
    $puppet_certname = $facts['networking']['fqdn']

    $cluster_nodes = lookup('cache::nodes')
    if $facts['networking']['fqdn'] =~ /^cp2/ {
        $targets = $cluster_nodes['usa']
    } elsif ( $facts['networking']['fqdn'] =~ /^cp3/ ) {
        $targets = array_concat(
            $cluster_nodes['lu'],
            $cluster_nodes['ja'],
            $cluster_nodes['au'],
        )
    } elsif ( $facts['networking']['fqdn'] =~ /^cp4/ )  {
        $targets = $cluster_nodes['usa']
    } elsif ( $facts['networking']['fqdn'] =~ /^cp5/ )  {
        $targets = $cluster_nodes['usa']
    } elsif ( $facts['networking']['fqdn'] =~ /^test151/ ) {
        $targets = $cluster_nodes['lu']
    }

    class { '::strongswan':
        puppet_certname => $puppet_certname,
        hosts           => $targets.filter |$target| { $target != '' },
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Strongswan]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['he-ipv6'] ) {
                "${value['networking']['ip']} ${value['networking']['interfaces']['he-ipv6']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
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
    ferm::service { 'ipsec 500':
        proto  => 'udp',
        port   => '500',
        srange => "(${firewall_rules_str})",
    }
    ferm::service { 'ipsec 4500':
        proto  => 'udp',
        port   => '4500',
        srange => "(${firewall_rules_str})",
    }
}
