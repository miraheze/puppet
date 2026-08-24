# @summary a shim define to support a common interface between ferm::client and nftables::client
# @param proto tcp or udp
# @param port a single port, or an array of ports, for a rule that covers more than one
#   discrete port. Exactly one of port or port_range must be given.
# @param port_range a colon-separated range like '5900:5999'. Exactly one of port or
#   port_range must be given.
# @param ensure the ensurable parameter
# @param desc an optional description, added as a comment
# @param prio the priority, meaning differs slightly by backend
# @param drange if not given, all destination addresses are allowed, otherwise only
#   traffic towards drange is allowed
# @param notrack set the rule with no state tracking
define firewall::client (
    Enum['tcp', 'udp']                       $proto,
    Optional[Nftables::Port]                 $port       = undef,
    Optional[VMlib::Portrange]               $port_range = undef,
    VMlib::Ensure                            $ensure     = present,
    String                                   $desc       = '',
    Integer[0, 99]                           $prio       = 10,
    Optional[Variant[String, Array[String]]] $drange     = undef,
    Boolean                                  $notrack    = false,
) {
    if ($port == undef) == ($port_range == undef) {
        fail("firewall::client: ${title}: exactly one of port or port_range must be given")
    }

    if $port_range != undef {
        $ferm_port = $port_range
    } elsif $port =~ Array {
        $ferm_port = "(${port.join(' ')})"
    } else {
        $ferm_port = $port
    }

    ferm::client { $title:
        ensure  => $ensure,
        port    => $ferm_port,
        proto   => $proto,
        desc    => $desc,
        prio    => $prio,
        drange  => $drange,
        notrack => $notrack,
    }

    nftables::client { $title:
        ensure     => $ensure,
        port       => $port,
        port_range => $port_range,
        proto      => $proto,
        desc       => $desc,
        prio       => $prio,
        drange     => $drange,
        notrack    => $notrack,
    }
}
