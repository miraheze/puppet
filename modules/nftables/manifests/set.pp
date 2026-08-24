# @summary declares a named nft set, referenced from rules elsewhere as @<name>_ipv4 / @<name>_ipv6
# @param ips the member addresses, a mix of IPv4 and IPv6 is fine, each family becomes its own set
# @param ensure the ensurable parameter
define nftables::set (
    Array[Stdlib::IP::Address] $ips,
    VMlib::Ensure              $ensure = present,
) {
    $ipv4_addrs = $ips.flatten.unique.filter |$ip| { $ip =~ Stdlib::IP::Address::V4 }
    $ipv6_addrs = $ips.flatten.unique.filter |$ip| { $ip =~ Stdlib::IP::Address::V6 }

    $v4_params = {
        'name'     => "${title}_ipv4",
        'set_type' => 'ipv4_addr',
        'addrs'    => $ipv4_addrs,
        'interval' => $ipv4_addrs.any |$addr| { '/' in $addr },
    }
    @file { "/etc/nftables/sets/${name}_ipv4.nft":
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => epp('nftables/set.epp', $v4_params),
        require => File['/etc/nftables/sets'],
        tag     => 'nft',
    }

    $v6_params = {
        'name'     => "${title}_ipv6",
        'set_type' => 'ipv6_addr',
        'addrs'    => $ipv6_addrs,
        'interval' => $ipv6_addrs.any |$addr| { '/' in $addr }
    }
    @file { "/etc/nftables/sets/${name}_ipv6.nft":
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => epp('nftables/set.epp', $v6_params),
        require => File['/etc/nftables/sets'],
        tag     => 'nft',
    }
}
