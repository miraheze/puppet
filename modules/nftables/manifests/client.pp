# @summary allow outbound connections on the specific protocol and destination port
# @param proto tcp or udp
# @param port a single port, or an array of ports, for a rule that covers more than one
#   discrete port. Exactly one of port or port_range must be given.
# @param port_range a colon-separated range like '5900:5999'. Exactly one of port or
#   port_range must be given.
# @param ensure the ensurable parameter
# @param desc an optional description, added as a comment to the .nft file
# @param prio fragments in a chain's directory load in filename order, this is the prefix
# @param drange if not given, all destination addresses are allowed. otherwise only
#   traffic towards drange is allowed. a bare CIDR, a parenthesised space separated
#   list, or an array.
# @param notrack if true, also exempt this port from connection tracking. this needs a
#   rule in output (for the outbound request), prerouting (for the reply), and an
#   explicit input accept, since without conntrack state the usual
#   "ct state established,related accept" rule at the top of input never matches the
#   reply traffic.
define nftables::client (
    Enum['tcp', 'udp']                       $proto,
    Optional[Nftables::Port]                 $port       = undef,
    Optional[VMlib::Portrange]               $port_range = undef,
    VMlib::Ensure                            $ensure     = present,
    String                                   $desc       = '',
    Integer[0, 99]                           $prio       = 10,
    Optional[Variant[String, Array[String]]] $drange     = undef,
    Boolean                                  $notrack    = false,
) {
    if ($port == undef) == ($port_range == undef) {
        fail("nftables::client: ${title}: exactly one of port or port_range must be given")
    }

    if $port_range != undef {
        $nft_port = regsubst($port_range, ':', '-', 'G')
    } elsif $port =~ Array {
        $nft_port = "{ ${port.join(', ')} }"
    } else {
        $nft_port = String($port)
    }

    $drange_split = nftables::split_addrs($drange)

    if $drange == undef {
        $output_lines = ["${proto} dport ${nft_port} accept"]
    } else {
        $output_lines = ['v4', 'v6'].map |$fam| {
            $daddrs = $drange_split[$fam]
            if $daddrs.empty {
                undef
            } else {
                $ip_kw = $fam ? { 'v4' => 'ip', default => 'ip6' }
                "${proto} dport ${nft_port} ${ip_kw} daddr { ${daddrs.join(', ')} } accept"
            }
        }.filter |$line| { $line != undef }
    }

    $content = @("CONTENT")
        # Managed by puppet
        # ${desc}
        ${output_lines.join("\n")}
        | CONTENT

    @file { sprintf('/etc/nftables/output/%02d_%s.nft', $prio, $title):
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => $content,
        require => File['/etc/nftables/output'],
        tag     => 'nft',
    }

    if $notrack {
        $output_notrack_content = @("OUTPUT")
            # Managed by puppet
            # ${desc}
            ${proto} dport ${nft_port} notrack
            | OUTPUT

        @file { sprintf('/etc/nftables/output/%02d_%s_client_notrack.nft', $prio, $title):
            ensure  => $ensure,
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            content => $output_notrack_content,
            require => File['/etc/nftables/output'],
            tag     => 'nft',
        }

        $prerouting_notrack_content = @("PREROUTING")
            # Managed by puppet
            # ${desc}
            ${proto} sport ${nft_port} notrack
            | PREROUTING

        @file { sprintf('/etc/nftables/prerouting/%02d_%s_client_notrack.nft', $prio, $title):
            ensure  => $ensure,
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            content => $prerouting_notrack_content,
            require => File['/etc/nftables/prerouting'],
            tag     => 'nft',
        }

        $input_accept_content = @("INPUT")
            # Managed by puppet
            # ${desc}
            ${proto} sport ${nft_port} accept
            | INPUT

        @file { sprintf('/etc/nftables/input/%02d_%s_client_notrack.nft', $prio, $title):
            ensure  => $ensure,
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            content => $input_accept_content,
            require => File['/etc/nftables/input'],
            tag     => 'nft',
        }
    }
}
