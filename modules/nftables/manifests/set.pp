# @summary declares a named nft set, referenced from rules elsewhere as @<name>_ipv4 / @<name>_ipv6
# @param ips the member addresses, a mix of IPv4 and IPv6 is fine, each family becomes its own set
# @param ensure the ensurable parameter
define nftables::set (
    Array[Stdlib::IP::Address] $ips,
    Enum['present', 'absent']  $ensure = present,
) {
    $ipv4_addrs = $ips.filter |$ip| { $ip =~ Stdlib::IP::Address::V4 }
    $ipv6_addrs = $ips.filter |$ip| { $ip =~ Stdlib::IP::Address::V6 }

    # each family's file is only ever present if that family actually has
    # members, even when $ensure is present overall, so a rule referencing
    # an empty family's set never gets created either. See
    # nftables::file::input call sites for the matching half of this.
    $ensure_v4 = ($ensure == 'present' and !$ipv4_addrs.empty) ? { true => 'present', default => 'absent' }
    $ensure_v6 = ($ensure == 'present' and !$ipv6_addrs.empty) ? { true => 'present', default => 'absent' }

    @file { "/etc/nftables/sets/${title}_ipv4.nft":
        ensure  => $ensure_v4,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => epp('nftables/set.epp', {
            'name'     => "${title}_ipv4",
            'set_type' => 'ipv4_addr',
            'addrs'    => $ipv4_addrs,
            'interval' => $ipv4_addrs.any |$addr| { $addr =~ /\// },
        }),
        require => File['/etc/nftables/sets'],
        tag     => 'nft',
    }

    @file { "/etc/nftables/sets/${title}_ipv6.nft":
        ensure  => $ensure_v6,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => epp('nftables/set.epp', {
            'name'     => "${title}_ipv6",
            'set_type' => 'ipv6_addr',
            'addrs'    => $ipv6_addrs,
            'interval' => $ipv6_addrs.any |$addr| { $addr =~ /\// },
        }),
        require => File['/etc/nftables/sets'],
        tag     => 'nft',
    }
}
