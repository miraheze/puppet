# @summary install a raw nft fragment into the input chain
# @param content the full content of the fragment
# @param ensure the ensurable parameter
# @param order fragments in a chain's directory load in filename order, this is the prefix
define nftables::file::input (
    String                     $content,
    Enum['present', 'absent']  $ensure = present,
    Integer[0, 99]             $order  = 0,
) {
    @file { sprintf('/etc/nftables/input/%02d_%s.nft', $order, $title):
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => $content,
        require => File['/etc/nftables/input'],
        tag     => 'nft',
    }
}
