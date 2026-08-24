# @summary a shim define to support a common interface between ferm::set and nftables::set
# @param ips the member addresses, a mix of IPv4 and IPv6 is fine
# @param ensure the ensurable parameter
define firewall::set (
    Array[Stdlib::IP::Address] $ips,
    VMlib::Ensure               $ensure = present,
) {
    ferm::set { $title:
        ips    => $ips,
        ensure => $ensure,
    }

    nftables::set { $title:
        ips    => $ips,
        ensure => $ensure,
    }
}
