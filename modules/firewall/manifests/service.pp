# @summary a shim define to support a common interface between firewall services
# @param proto tcp or udp
# @param port a single port, or an array of ports, for a rule that covers more than one
#   discrete port. Exactly one of port or port_range must be given.
# @param port_range a [low, high] tuple, both real port numbers. Exactly one of port or
#   port_range must be given.
# @param ensure the ensurable parameter
# @param desc an optional description, added as a comment
# @param prio the priority, meaning differs slightly by backend
# @param srange if not given, all source addresses are allowed, otherwise only traffic
#   coming from srange is allowed
# @param drange if not given, all destination addresses are allowed, otherwise only
#   traffic incoming to drange is allowed
# @param src_sets names of firewall::set resources to also allow traffic from. additive
#   with srange, not a further restriction of it.
# @param dst_sets names of firewall::set resources to also allow traffic towards.
#   additive with drange, not a further restriction of it.
# @param notrack set the rule with no state tracking
define firewall::service (
    VMlib::Protocol                          $proto,
    Optional[Nftables::Port]                 $port       = undef,
    Optional[Firewall::Portrange]            $port_range = undef,
    VMlib::Ensure                            $ensure     = present,
    String                                   $desc       = '',
    Integer[0, 99]                           $prio       = 10,
    Optional[Variant[String, Array[String]]] $srange     = undef,
    Optional[Variant[String, Array[String]]] $drange     = undef,
    Optional[Array[String[1]]]               $src_sets   = undef,
    Optional[Array[String[1]]]               $dst_sets   = undef,
    Boolean                                  $notrack    = false,
) {
    if ($port == undef) == ($port_range == undef) {
        fail("firewall::service: ${title}: exactly one of port or port_range must be given")
    }

    if $src_sets != undef {
        $src_sets.each |$set_name| {
            unless defined(Firewall::Set[$set_name]) {
                firewall::set { $set_name:
                    ips => network::host_group($set_name),
                }
            }
        }
    }

    if $dst_sets != undef {
        $dst_sets.each |$set_name| {
            unless defined(Firewall::Set[$set_name]) {
                firewall::set { $set_name:
                    ips => network::host_group($set_name),
                }
            }
        }
    }

    nftables::service { $title:
        ensure     => $ensure,
        port       => $port,
        port_range => $port_range,
        proto      => $proto,
        desc       => $desc,
        prio       => $prio,
        srange     => $srange,
        drange     => $drange,
        src_sets   => $src_sets,
        dst_sets   => $dst_sets,
        notrack    => $notrack,
    }
}
