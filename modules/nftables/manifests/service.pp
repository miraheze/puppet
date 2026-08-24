# @summary allow incoming connections on the specific protocol and port
# @param proto tcp or udp
# @param port a single port, or an array of ports, for a rule that covers more than one
#   discrete port. Exactly one of port or port_range must be given.
# @param port_range a [low, high] tuple, both real port numbers. Exactly one of port or
#   port_range must be given.
# @param ensure the ensurable parameter
# @param desc an optional description, added as a comment to the .nft file
# @param prio fragments in a chain's directory load in filename order, this is the prefix
# @param srange if not given, all source addresses are allowed. otherwise only traffic
#   coming from srange is allowed. a bare CIDR, a parenthesised space separated list, or
#   an array.
# @param drange same as srange, but for destination addresses
# @param src_sets names of nftables::set resources to also allow traffic from, declared
#   separately (see firewall::set). combined with srange as an OR - traffic is allowed
#   if it matches srange or any of src_sets. if drange or dst_sets is also given, that
#   combination is an AND - every (source, destination) pairing gets its own rule.
# @param dst_sets same as src_sets, but for destination addresses
# @param notrack if true, also exempt this port from connection tracking. this needs a
#   rule in both prerouting (for the inbound request) and output (for the reply).
define nftables::service (
    VMlib::Protocol                          $proto,
    Optional[Nftables::Port]                 $port       = undef,
    Optional[Firewall::Portrange]            $port_range = undef,
    VMlib::Ensure                            $ensure     = present,
    String                                   $desc       = '',
    Integer[0, 99]                           $prio       = 10,
    Optional[Variant[String, Array[String]]] $srange     = undef,
    Optional[Variant[String, Array[String]]] $drange     = undef,
    Optional[Array[String[1]]]               $src_sets   = undef,
    Optional[Array[String[1]]]               $dst_sets   = undef,
    Boolean                                  $notrack    = false,
) {
    $nft_port = nftables::port_stmt($port, $port_range)

    $src_ips = nftables::normalize_range($srange)
    $dst_ips = nftables::normalize_range($drange)

    $l3_stmts = nftables::ip_stmt(4, $src_ips, $dst_ips, $src_sets, $dst_sets) +
    nftables::ip_stmt(6, $src_ips, $dst_ips, $src_sets, $dst_sets)

    if $l3_stmts.empty {
        $input_lines = ["${proto} dport ${nft_port} accept"]
    } else {
        $input_lines = $l3_stmts.map |$clauses| {
            "${proto} dport ${nft_port} ${clauses.join(' ')} accept"
        }
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
