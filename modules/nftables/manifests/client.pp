# @summary allow outbound connections on the specific protocol and destination port
# @param proto tcp or udp
# @param port a single port, or an array of ports, for a rule that covers more than one
#   discrete port. Exactly one of port or port_range must be given.
# @param port_range a [low, high] tuple, both real port numbers. Exactly one of port or
#   port_range must be given.
# @param ensure the ensurable parameter
# @param desc an optional description, added as a comment to the .nft file
# @param prio fragments in a chain's directory load in filename order, this is the prefix
# @param drange if not given, all destination addresses are allowed. otherwise only
#   traffic towards drange is allowed. a bare CIDR, a parenthesised space separated
#   list, or an array.
# @param dst_sets names of nftables::set resources to also allow traffic towards,
#   declared separately (see firewall::set). combined with drange as an OR.
# @param notrack if true, also exempt this port from connection tracking. this needs a
#   rule in output (for the outbound request), prerouting (for the reply), and an
#   explicit input accept, since without conntrack state the usual
#   "ct state established,related accept" rule at the top of input never matches the
#   reply traffic.
define nftables::client (
    VMlib::Protocol                          $proto,
    Optional[Nftables::Port]                 $port       = undef,
    Optional[Firewall::Portrange]            $port_range = undef,
    VMlib::Ensure                            $ensure     = present,
    String                                   $desc       = '',
    Integer[0, 99]                           $prio       = 10,
    Optional[Variant[String, Array[String]]] $drange     = undef,
    Optional[Array[String[1]]]               $dst_sets   = undef,
    Boolean                                  $notrack    = false,
) {
    $nft_port = nftables::port_stmt($port, $port_range)

    $dst_ips = nftables::normalize_range($drange)

    # a client rule has no source restriction concept, "source" is always
    # this host, so src_ips/src_sets are fixed to undef here - only the
    # destination side ever has a range or sets to combine.
    $l3_stmts = nftables::ip_stmt(4, undef, $dst_ips, undef, $dst_sets) +
    nftables::ip_stmt(6, undef, $dst_ips, undef, $dst_sets)

    if $l3_stmts.empty {
        $output_lines = ["${proto} dport ${nft_port} accept"]
    } else {
        $output_lines = $l3_stmts.map |$clauses| {
            "${proto} dport ${nft_port} ${clauses.join(' ')} accept"
        }
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
