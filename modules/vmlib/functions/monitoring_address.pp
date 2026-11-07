function vmlib::monitoring_address (
    Hash $networking,
) >> Optional[String] {
    $ifaces = $networking['interfaces'] ? {
        Hash    => $networking['interfaces'],
        default => {},
    }

    $public_ipv4 = $ifaces['ens18'] ? {
        Hash    => $ifaces['ens18']['ip'],
        default => $networking['ip'],
    }

    if $ifaces['vmbr1'] {
        $ifaces['vmbr1']['ip']
    } elsif $ifaces['ens19'] and $ifaces['ens18'] {
        $ifaces['ens19']['ip']
    } elsif !$ifaces['ens19'] and $public_ipv4 =~ Stdlib::IP::Address::V4::Nosubnet {
        $public_ipv4
    } elsif $ifaces['ens18'] {
        $ifaces['ens18']['ip6']
    } else {
        $networking['ip6']
    }
}
