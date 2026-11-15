# @summary normalizes a loose srange/drange value into a flat address array
#
# srange/drange show up in this codebase as a bare CIDR, like '10.0.0.0/8',
# as a parenthesised space separated list, like the strings
# vmlib::generate_firewall_ip builds, or occasionally as an actual array.
# nftables::ip_addr_stmt wants a plain Array[Stdlib::IP::Address] and does
# its own per-family filtering, so this just flattens whichever of those
# shapes was given into that, without touching family at all.
function nftables::normalize_range(Optional[Variant[String, Array[String]]] $range) >> Optional[Array[Stdlib::IP::Address]] {
    if $range == undef or $range == '' or $range == [] {
        undef
    } elsif $range =~ Array {
        $range
    } else {
        $stripped = regsubst($range, '^\(|\)$', '', 'G')
        $stripped.split(/\s+/).filter |$addr| { $addr != '' }
    }
}
