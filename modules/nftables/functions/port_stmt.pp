# @summary formats a port or port_range into nft match syntax
# @param port a single port, or an array of ports for a discrete-port-list match
# @param port_range a [low, high] tuple, both real port numbers
#
# Exactly one of port or port_range must be given. Only the port value itself
# is formatted here, not a full match clause, since callers need the dport or
# sport keyword plugged in separately - nftables::service uses the same
# formatted value for both a dport accept rule and, for notrack, a matching
# sport line elsewhere.
function nftables::port_stmt(
    Optional[Nftables::Port]      $port       = undef,
    Optional[Firewall::Portrange] $port_range = undef,
) >> String {
    if ($port == undef) == ($port_range == undef) {
        fail('nftables::port_stmt: exactly one of port or port_range must be given')
    }

    if $port_range != undef {
        "${port_range[0]}-${port_range[1]}"
    } elsif $port =~ Array {
        "{ ${port.join(', ')} }"
    } else {
        String($port)
    }
}
