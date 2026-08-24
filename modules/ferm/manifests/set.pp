# @summary declares a named ferm set, referenced from rules elsewhere as $<name>
# @param ips the member addresses, a mix of IPv4 and IPv6 is fine - ferm's own
#   domain (ip ip6) expansion already filters a mixed list by family per
#   domain for inline srange/drange values, and does the same for a @def set.
# @param ensure the ensurable parameter
define ferm::set (
    Array[Stdlib::IP::Address] $ips,
    Enum['present', 'absent']  $ensure = present,
) {
    ferm::conf { "set_${title}":
        ensure  => $ensure,
        prio    => '00',
        content => "@def \$${title} = (${ips.join(' ')});\n",
    }
}
