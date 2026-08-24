function vmlib::generate_firewall_ip (
    Optional[String[1]] $subquery = undef
) >> String {
    join(
        puppetdb::query_facts(['networking'], $subquery).values.map |$_facts| {
            if ($_facts['networking']['interfaces']['vmbr1']) {
                "${_facts['networking']['interfaces']['vmbr1']['ip']} ${_facts['networking']['ip']} ${_facts['networking']['ip6']}"
            } elsif ($_facts['networking']['interfaces']['ens19'] and $_facts['networking']['interfaces']['ens18']) {
                "${_facts['networking']['interfaces']['ens19']['ip']} ${_facts['networking']['interfaces']['ens18']['ip']} ${_facts['networking']['interfaces']['ens18']['ip6']}"
            } elsif ($_facts['networking']['interfaces']['ens18']) {
                "${_facts['networking']['interfaces']['ens18']['ip']} ${_facts['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${_facts['networking']['ip']} ${_facts['networking']['ip6']}"
            }
        }.flatten.sort.unique,
        ' '
    )
}
