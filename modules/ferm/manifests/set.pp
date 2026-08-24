# @summary declares a named ferm set, referenced from rules elsewhere as $<name>
# @param ips the member addresses, a mix of IPv4 and IPv6 is fine
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
