# @summary allow incoming connections on the specific protocol and port
# @param proto tcp or udp
# @param port a single port, or an array of ports, for a rule that covers more than one
#   discrete port. Exactly one of port or port_range must be given.
# @param port_range a colon-separated range like '5900:5999'. Exactly one of port or
#   port_range must be given.
# @param ensure the ensurable parameter
# @param desc an optional description, added as a comment to the .nft file
# @param prio fragments in a chain's directory load in filename order, this is the prefix
# @param srange if not given, all source addresses are allowed. otherwise only traffic
#   coming from srange is allowed. a bare CIDR, a parenthesised space separated list, or
#   an array.
# @param drange same as srange, but for destination addresses
# @param notrack if true, also exempt this port from connection tracking. this needs a
#   rule in both prerouting (for the inbound request) and output (for the reply).
define nftables::service (
    Enum['tcp', 'udp']                       $proto,
    Optional[Nftables::Port]                 $port       = undef,
    Optional[VMlib::Portrange]               $port_range = undef,
    VMlib::Ensure                            $ensure     = present,
    String                                   $desc       = '',
    Integer[0, 99]                           $prio       = 10,
    Optional[Variant[String, Array[String]]] $srange     = undef,
    Optional[Variant[String, Array[String]]] $drange     = undef,
    Boolean                                  $notrack    = false,
) {
    if ($port == undef) == ($port_range == undef) {
        fail("nftables::service: ${title}: exactly one of port or port_range must be given")
    }

    if $port_range != undef {
        $nft_port = regsubst($port_range, ':', '-', 'G')
    } elsif $port =~ Array {
        $nft_port = "{ ${port.join(', ')} }"
    } else {
        $nft_port = String($port)
    }

    if $srange == undef and $drange == undef {
        $input_lines = ["${proto} dport ${nft_port} accept"]
    } else {
        $srange_split = nftables::split_addrs($srange)
        $drange_split = nftables::split_addrs($drange)

        $input_lines = ['v4', 'v6'].map |$fam| {
            $saddrs = $srange_split[$fam]
            $daddrs = $drange_split[$fam]
            $skip_family = ($srange != undef and $saddrs.empty) or ($drange != undef and $daddrs.empty)

            if $skip_family {
                undef
            } else {
                $ip_kw    = $fam ? { 'v4' => 'ip', default => 'ip6' }
                $s_clause = $srange =~ Undef ? { true => '', default => " ${ip_kw} saddr { ${saddrs.join(', ')} }" }
                $d_clause = $drange =~ Undef ? { true => '', default => " ${ip_kw} daddr { ${daddrs.join(', ')} }" }
                "${proto} dport ${nft_port}${s_clause}${d_clause} accept"
            }
        }.filter |$line| { $line != undef }
    }

    $content = @("CONTENT")
        # Managed by puppet
        # ${desc}
        ${input_lines.join("\n")}
        | CONTENT

    @file { sprintf('/etc/nftables/input/%02d_%s.nft', $prio, $title):
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => $content,
        require => File['/etc/nftables/input'],
        tag     => 'nft',
    }

    if $notrack {
        $prerouting_content = @("PREROUTING")
            # Managed by puppet
            # ${desc}
            ${proto} dport ${nft_port} notrack
            | PREROUTING

        @file { sprintf('/etc/nftables/prerouting/%02d_%s_service_notrack.nft', $prio, $title):
            ensure  => $ensure,
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            content => $prerouting_content,
            require => File['/etc/nftables/prerouting'],
            tag     => 'nft',
        }

        $output_content = @("OUTPUT")
            # Managed by puppet
            # ${desc}
            ${proto} sport ${nft_port} notrack
            | OUTPUT

        @file { sprintf('/etc/nftables/output/%02d_%s_service_notrack.nft', $prio, $title):
            ensure  => $ensure,
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            content => $output_content,
            require => File['/etc/nftables/output'],
            tag     => 'nft',
        }
    }
}
