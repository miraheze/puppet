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

    unless $provider == 'none' {
        class { 'ferm':
            ensure => $ferm_ensure,
        }

        class { 'nftables':
            ensure => $nftables_ensure,
        }
    }
}
