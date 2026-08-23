# ferm addresses show up in this codebase either as a bare CIDR, like
# '10.0.0.0/8', as a parenthesised, space separated list, like the
# strings vmlib::generate_firewall_ip builds, or occasionally as an actual
# array, like ['127.0.0.1']. nftables has no single match expression that
# spans both IPv4 and IPv6, so every caller that wants to turn one of
# those into nft rule text needs the addresses split into their own
# family first.
function nftables::split_addrs(Optional[Variant[String, Array[String]]] $range) >> Struct[{'v4' => Array[String], 'v6' => Array[String]}] {
    if $range == undef or $range == '' or $range == [] {
        return { 'v4' => [], 'v6' => [] }
    }

    if $range =~ Array {
        $addrs = $range.filter |$addr| { $addr != '' }
    } else {
        $stripped = regsubst($range, '^\(|\)$', '', 'G')
        $addrs    = $stripped.split(/\s+/).filter |$addr| { $addr != '' }
    }

    {
        'v4' => $addrs.filter |$addr| { $addr !~ /:/ },
        'v6' => $addrs.filter |$addr| { $addr =~ /:/ },
    }
}
