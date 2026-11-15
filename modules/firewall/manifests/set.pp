# @summary a shim define to support a common interface between firewall sets
# @param ips the member addresses, a mix of IPv4 and IPv6 is fine
# @param ensure the ensurable parameter
define firewall::set (
    Array[Stdlib::IP::Address] $ips,
    VMlib::Ensure              $ensure = present,
) {
    nftables::set { $title:
        ensure => $ensure,
        ips    => $ips,
    }
}
