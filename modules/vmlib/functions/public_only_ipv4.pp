function vmlib::public_only_ipv4 () >> Array[String] {
    $query = @("PQL")
        resources { type = 'Class' and title = 'Base' }
        | PQL

    puppetdb::query_facts(['networking'], $query).values
        .map |$node_facts| {
            $net = $node_facts['networking']
            $ifaces = $net['interfaces'] ? {
                Hash    => $net['interfaces'],
                default => {},
            }

            if $ifaces['vmbr1'] or $ifaces['ens19'] {
                undef
            } elsif $ifaces['ens18'] =~ Hash {
                $ifaces['ens18']['ip']
            } else {
                $net['ip']
            }
        }
        .filter |$ip| { $ip =~ Stdlib::IP::Address::V4::Nosubnet }
        .sort
        .unique
}
