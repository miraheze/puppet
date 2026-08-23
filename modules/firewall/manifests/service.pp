# @summary a shim define to support a common interface between ferm::service and nftables::service
# @param proto tcp or udp
# @param port a single port, or a colon-separated ferm-style range like '5900:5999'
# @param ensure the ensurable parameter
# @param desc an optional description, added as a comment
# @param prio the priority, meaning differs slightly by backend, see ferm::service and nftables::service
# @param srange if not given, all source addresses are allowed, otherwise only traffic
#   coming from srange is allowed
# @param drange if not given, all destination addresses are allowed, otherwise only
#   traffic incoming to drange is allowed
# @param notrack set the rule with no state tracking
define firewall::service (
    Enum['tcp', 'udp']                       $proto,
    Variant[Stdlib::Port, String[1]]         $port,
    Enum['present', 'absent']                $ensure  = present,
    String                                   $desc    = '',
    Integer[0, 99]                           $prio    = 10,
    Optional[Variant[String, Array[String]]] $srange  = undef,
    Optional[Variant[String, Array[String]]] $drange  = undef,
    Boolean                                  $notrack = false,
) {
    ferm::service { $title:
        ensure  => $ensure,
        port    => $port,
        proto   => $proto,
        desc    => $desc,
        prio    => $prio,
        srange  => $srange,
        drange  => $drange,
        notrack => $notrack,
    }

    nftables::service { $title:
        ensure  => $ensure,
        port    => $port,
        proto   => $proto,
        desc    => $desc,
        prio    => $prio,
        srange  => $srange,
        drange  => $drange,
        notrack => $notrack,
    }
}
