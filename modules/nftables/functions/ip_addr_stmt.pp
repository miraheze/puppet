# @summary builds saddr/daddr match clauses for one address family
# @param ver 4 or 6, which address family this call is for
# @param dir saddr or daddr
# @param ips literal addresses to match, any not in this family are dropped
# @param sets names of nftables::set resources to also match against
#
# Returns an array of independent clauses, any one of which matching is
# enough (e.g. ["ip saddr { 10.0.0.0/8 }", "ip saddr @BASTION_HOSTS_ipv4"]),
# an empty array if neither ips nor sets were given (no restriction at all),
# or undef if ips were given but none belong to this family - the caller
# needs to skip this family entirely in that case, rather than emit an
# unrestricted rule for it.
function nftables::ip_addr_stmt(
    Variant[Integer[4, 4], Integer[6, 6]] $ver,
    Enum['saddr', 'daddr']                $dir,
    Optional[Array[Stdlib::IP::Address]]  $ips,
    Optional[Array[String[1]]]            $sets,
) >> Optional[Array[String[1]]] {
    $type_ver = $ver ? {
        4 => Stdlib::IP::Address::V4,
        6 => Stdlib::IP::Address::V6,
    }
    $ip_ver = $ver ? {
        4 => 'ip',
        6 => 'ip6',
    }

    if $ips != undef {
        $ip_addrs = $ips.filter |$addr| { $addr =~ $type_ver }.sort.unique
        $ip_stmts = $ip_addrs.empty ? {
            true    => undef,
            default => ["${ip_ver} ${dir} { ${ip_addrs.join(', ')} }"],
        }
    } else {
        $ip_stmts = []
    }

    $set_stmts = $sets == undef ? {
        true    => [],
        default => $sets.map |$set_name| { "${ip_ver} ${dir} @${set_name}_ipv${ver}" },
    }

    if $ip_stmts == undef {
        $set_stmts.empty ? { true => undef, default => $set_stmts }
    } else {
        $ip_stmts + $set_stmts
    }
}
