# @summary add raw nft statements to one of the base table's chains
# @param ensure the ensurable parameter
# @param desc an optional description, added as a comment to the .nft file
# @param prio fragments in a chain's directory load in filename order, this is the prefix
# @param chain which base table chain to add these statements to
# @param rules one nft statement per array entry, each becomes its own line
define nftables::rules (
    Array[String]    $rules,
    VMlib::Ensure    $ensure = present,
    Optional[String] $desc   = undef,
    Integer[0, 99]   $prio   = 10,
    Nftables::Chain  $chain  = 'input',
) {
    $content = @("CONTENT")
        # Managed by puppet
        # ${desc}
        ${rules.join("\n")}
        | CONTENT

    @file { sprintf('/etc/nftables/%s/%02d_%s.nft', $chain, $prio, $title):
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => $content,
        require => File["/etc/nftables/${chain}"],
        tag     => 'nft',
    }
}
