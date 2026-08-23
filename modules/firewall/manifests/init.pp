# @summary wrapper class to provide a common interface to ferm and nftables
# @param provider which firewall backend, or backends, this host uses
class firewall (
    Firewall::Provider $provider = 'ferm',
) {
    $ferm_ensure = $provider ? {
        'ferm'  => 'present',
        'both'  => 'present',
        default => 'absent',
    }

    $nftables_ensure = $provider ? {
        'nftables' => 'present',
        'both'     => 'present',
        default    => 'absent',
    }

    # Both backends are always included, just with ensure toggled, rather
    # than only conditionally including nftables the way Wikimedia's
    # operations-puppet does. That's a deliberate difference: it means a
    # ferm-only host still actively ensures nftables is absent instead of
    # just never touching it, so nftables can't end up installed and
    # forgotten there by some other means.
    unless $provider == 'none' {
        class { 'ferm':
            ensure => $ferm_ensure,
        }

        class { 'nftables':
            ensure => $nftables_ensure,
        }
    }
}
