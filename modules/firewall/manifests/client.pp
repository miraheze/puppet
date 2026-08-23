# @summary a shim define to support a common interface between ferm::client and nftables::client
# @param proto tcp or udp
# @param port a single port, or a colon-separated ferm-style range like '5900:5999'
# @param ensure the ensurable parameter
# @param desc an optional description, added as a comment
# @param prio the priority, meaning differs slightly by backend, see ferm::client and nftables::client
# @param drange if not given, all destination addresses are allowed, otherwise only
#   traffic towards drange is allowed
# @param notrack set the rule with no state tracking
define firewall::client (
    Enum['tcp', 'udp']                       $proto,
    Variant[Stdlib::Port, String[1]]         $port,
    Enum['present', 'absent']                $ensure  = present,
    String                                   $desc    = '',
    Integer[0, 99]                           $prio    = 10,
    Optional[Variant[String, Array[String]]] $drange  = undef,
    Boolean                                  $notrack = false,
) {
    ferm::client { $title:
        proto   => $proto,
        port    => $port,
        ensure  => $ensure,
        desc    => $desc,
        prio    => $prio,
        drange  => $drange,
        notrack => $notrack,
    }

    nftables::client { $title:
        proto   => $proto,
        port    => $port,
        ensure  => $ensure,
        desc    => $desc,
        prio    => $prio,
        drange  => $drange,
        notrack => $notrack,
    }
}
