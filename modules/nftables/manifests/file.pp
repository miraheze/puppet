# @summary deploy a whole top level nft file, for things like a complete table
#   definition that doesn't belong inside one of the base table's chains.
#   used by base::firewall to deploy the base ruleset itself.
# @param content the full content of the file
# @param ensure the ensurable parameter
# @param order files at the top level of /etc/nftables load in filename order,
#   this is the prefix. the base ruleset itself uses 100, so anything that
#   needs to exist before it can use a lower order, and anything that depends
#   on it existing already can use a higher one.
define nftables::file (
    String                    $content,
    Enum['present', 'absent'] $ensure = present,
    Integer[0, 999]           $order  = 0,
) {
    @file { sprintf('/etc/nftables/%03d_%s_puppet.nft', $order, $title):
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => $content,
        require => File['/etc/nftables'],
        tag     => 'nft',
    }
}
