# @summary builds a combined ferm range string from a literal range and/or named sets
#
# ferm's saddr/daddr directive accepts a parenthesised, space separated list
# where each entry can be either a literal address/CIDR or a $SETNAME
# reference to an @def declared elsewhere (see ferm::set), mixed freely in
# the same list. This flattens whatever combination of literal range and
# named sets a caller gave into that single ferm-syntax string, so
# ferm::service/ferm::client never need to know sets exist at all - they
# just see an ordinary range value, the same as they always have.
function firewall::ferm_range(
    Optional[Variant[String, Array[String]]] $range,
    Optional[Array[String[1]]]               $sets = undef,
) >> Optional[String] {
    $range_tokens = if $range == undef {
        []
    } elsif $range =~ Array {
        $range
    } else {
        $stripped = regsubst($range, '^\(|\)$', '', 'G')
        $stripped.split(/\s+/).filter |$token| { $token != '' }
    }

    $set_tokens = if $sets == undef {
        []
    } else {
        $sets.map |$set_name| { "\$${set_name}" }
    }

    $tokens = $range_tokens + $set_tokens

    if $tokens.empty {
        undef
    } elsif $tokens.length == 1 {
        $tokens[0]
    } else {
        "(${tokens.join(' ')})"
    }
}
