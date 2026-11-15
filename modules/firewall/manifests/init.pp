# @summary wrapper class to provide a common interface for firewall backends
# @param provider which firewall backend, or backends, this host uses
class firewall (
    Firewall::Provider $provider = 'nftables',
) {
    $nftables_ensure = $provider ? {
        'nftables' => 'present',
        'both'     => 'present',
        default    => 'absent',
    }

    unless $provider == 'none' {
        class { 'nftables':
            ensure => $nftables_ensure,
        }
    }
}
