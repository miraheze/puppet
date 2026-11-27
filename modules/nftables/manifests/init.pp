class nftables (
    VMlib::Ensure $ensure = 'absent',
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

    systemd::service { 'nftables':
        ensure         => $ensure,
        content        => systemd_template('nftables'),
        override       => true,
        restart        => true,
        service_params => {
            hasrestart => true,
            restart    => '/usr/bin/systemctl reload nftables',
        },
    }

    file { '/etc/nftables.conf':
        ensure => absent,
    }

    file { '/etc/nftables':
        ensure  => directory,
        purge   => $ensure == 'present',
        recurse => true,
    }

    # each of these holds puppet-managed fragments. input, output and
    # prerouting get included by the matching chain in the base table, see
    # base::firewall. notrack holds the exceptions from connection tracking
    # and is included by the prerouting chain, since that is the only place
    # notrack can take effect. sets holds named address sets declared with
    # nftables::set, referenced from rules elsewhere with @setname.
    ['input', 'output', 'prerouting', 'notrack', 'sets'].each |$dir| {
        file { "/etc/nftables/${dir}":
            ensure  => directory,
            purge   => $ensure == 'present',
            recurse => true,
            require => File['/etc/nftables'],
        }
    }

    file { '/etc/nftables/main.nft':
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
