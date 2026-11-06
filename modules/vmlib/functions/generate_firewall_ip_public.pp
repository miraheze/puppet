function vmlib::generate_firewall_ip_public (
    String[1] $subquery,
    Hash      $networking,
) >> String {
    $addresses = vmlib::generate_firewall_ip($subquery)
    $ifaces = $networking['interfaces'] ? {
        Hash    => $networking['interfaces'],
        default => {},
    }

    if $ifaces['vmbr1'] or $ifaces['ens19'] {
        $result = $addresses
    } else {
        $bastion_query = @("PQL")
            resources { type = 'Class' and title = 'Role::Bastion' }
            | PQL
        $bastion_addresses = vmlib::generate_firewall_ip($bastion_query)
        $result = "${addresses} ${bastion_addresses}"
    }

    $result
}
