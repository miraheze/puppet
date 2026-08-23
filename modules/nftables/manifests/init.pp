# nftables is the successor to iptables/ferm for packet filtering on Linux.
#
# a static top level ruleset (files/main.nft) just flushes and includes every
# *puppet.nft file it finds, in filename order. Fragments that belong
# inside a specific base chain get dropped into that chain's own
# directory (input/output/prerouting) instead of a single flat conf.d, so
# a rule never needs to say which table or chain it targets, only which
# directory. The actual base table with its policies and hooks is
# deployed separately, by base::firewall.
#
# @param ensure present installs and enables nftables. absent purges it.
class nftables (
    Enum['present', 'absent'] $ensure = 'absent',
) {
    package { 'nftables':
        ensure => stdlib::ensure($ensure, 'package'),
    }

    # if the ensure is absent, we don't want the service running.
    if $ensure == 'absent' {
        systemd::mask { 'nftables.service': }
    } else {
        systemd::unmask { 'nftables.service': }
    }

    service { 'nftables':
        ensure  => stdlib::ensure($ensure, 'service'),
        enable  => $ensure == 'present',
        require => Package['nftables'],
    }

    file { '/etc/nftables':
        ensure  => stdlib::ensure($ensure, 'directory'),
        purge   => true,
        recurse => true,
    }

    # each of these holds puppet-managed fragments included by the
    # matching chain in the base table, see base::firewall. notrack
    # fragments land directly in whichever of these chains they need to
    # affect (see nftables::service and nftables::client) rather than a
    # separate notrack directory, since a service needs its notrack rule
    # in prerouting while a client needs its matching rule in output, and
    # putting both cases in one shared directory made it easy to only wire
    # up half of that.
    ['input', 'output', 'prerouting'].each |$dir| {
        file { "/etc/nftables/${dir}":
            ensure  => stdlib::ensure($ensure, 'directory'),
            purge   => true,
            recurse => true,
            require => File['/etc/nftables'],
        }
    }

    file { '/etc/nftables.conf':
        ensure  => stdlib::ensure($ensure, 'file'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/nftables/main.nft',
        require => File['/etc/nftables'],
        notify  => Service['nftables'],
    }

    if $ensure == 'present' {
        # rules declared elsewhere are virtual resources for cases where
        # they are defined in a class but the host doesn't have nftables
        # enabled.
        File <| tag == 'nft' |> ~> Service['nftables']
    }
}
