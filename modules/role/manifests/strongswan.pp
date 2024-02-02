class role::strongswan (
    Optional[Any] $hosts = undef
) {
    $puppet_certname = $::fqdn

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
}
