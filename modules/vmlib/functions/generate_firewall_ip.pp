function vmlib::generate_firewall_ip (
    Optional[String[1]] $subquery = undef
) >> String {
    join(
        puppetdb::query_facts(['networking'], $subquery).values.map |$_facts| {
            if ( $_facts['networking']['interfaces']['vmbr1'] ) {
                "${value['value']['interfaces']['vmbr1']['ip']} ${value['value']['ip']} ${value['value']['ip6']}"
            } elsif ( $_facts['networking']['interfaces']['ens19'] and $_facts['networking']['interfaces']['ens18'] ) {
                "${value['value']['interfaces']['ens19']['ip']} ${value['value']['interfaces']['ens18']['ip']} ${value['value']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['value']['interfaces']['ens18'] ) {
                "${value['value']['interfaces']['ens18']['ip']} ${value['value']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['value']['ip']} ${value['value']['ip6']}"
            }
        }.flatten.sort.unique,
        ' '
    )
}
