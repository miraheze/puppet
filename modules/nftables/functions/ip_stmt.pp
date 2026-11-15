# @summary combines saddr and daddr clauses into [src, dst] pairs for one address family
# @param ver 4 or 6, which address family this call is for
# @param src_ips literal source addresses, see nftables::ip_addr_stmt
# @param dst_ips literal destination addresses, see nftables::ip_addr_stmt
# @param src_sets names of nftables::set resources to match as source
# @param dst_sets names of nftables::set resources to match as destination
#
# Returns an array of clause-lists, each one a small array of 1 or 2 match
# clauses meant to be joined together into a single rule line. If both a
# source and a destination restriction were given, every combination of
# (a source clause, a destination clause) is returned, since a rule needs
# to require both at once, not just either - specifying "from BASTION_HOSTS"
# and "to 192.168.1.1" together should mean traffic from a bastion host
# towards that one address specifically, not "from any bastion host" OR
# "to that address from anywhere", which is what two independent rules
# would actually enforce.
function nftables::ip_stmt(
    Variant[Integer[4, 4], Integer[6, 6]] $ver,
    Optional[Array[Stdlib::IP::Address]]  $src_ips,
    Optional[Array[Stdlib::IP::Address]]  $dst_ips,
    Optional[Array[String[1]]]            $src_sets,
    Optional[Array[String[1]]]            $dst_sets,
) >> Array[Array[String[1]]] {
    $src_stmts = nftables::ip_addr_stmt($ver, 'saddr', $src_ips, $src_sets)
    $dst_stmts = nftables::ip_addr_stmt($ver, 'daddr', $dst_ips, $dst_sets)

    if $src_stmts == undef or $dst_stmts == undef {
        []
    } elsif $src_stmts.empty and $dst_stmts.empty {
        []
    } elsif $src_stmts.empty {
        $dst_stmts.map |$dst_stmt| { [$dst_stmt] }
    } elsif $dst_stmts.empty {
        $src_stmts.map |$src_stmt| { [$src_stmt] }
    } else {
        $src_stmts.reduce([]) |$memo, $src_stmt| {
            $dst_stmts.reduce($memo) |$memo2, $dst_stmt| {
                $memo2 + [[$src_stmt, $dst_stmt]]
            }
        }
    }
}
