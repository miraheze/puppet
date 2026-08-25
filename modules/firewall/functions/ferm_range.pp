# @summary builds a combined ferm range string from a literal range and/or named sets
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
