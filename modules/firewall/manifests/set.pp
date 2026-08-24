# @summary a shim define to support a common interface between ferm::set and nftables::set
# @param ips the member addresses, a mix of IPv4 and IPv6 is fine
# @param ensure the ensurable parameter
#
# Wikimedia's operations-puppet keeps its ferm set definitions (a defs.erb
# template) and its nftables set definitions (profile::firewall::nftables_base_sets)
# as two separately hand-authored files, with a comment warning to update both
# whenever one changes. That's exactly the kind of drift this whole migration
# has been trying to eliminate elsewhere, so this generates both backends from
# one set of parameters instead, the same way firewall::service and
# firewall::client already do.
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
