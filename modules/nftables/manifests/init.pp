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

    # systemd::service manages the service{} resource for us and takes
    # care of the ensure/enable wiring, but masking still needs handling
    # separately above since neither systemd::service nor systemd::unit
    # touch that.
    #
    # The override replaces both ExecStart and ExecReload to point at
    # /etc/nftables/main.nft instead of the package's default
    # /etc/nftables.conf. That's deliberate: /etc/nftables.conf is a
    # conffile the debian package itself ships and owns, so leaving our
    # config there means a future nftables package upgrade can prompt to
    # overwrite it, or silently drop a .dpkg-dist next to it. Deploying
    # to a path the package doesn't know about avoids that entirely.
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

    # the package's own default config file, unused now that the systemd
    # override points ExecStart/ExecReload at /etc/nftables/main.nft
    # instead. Kept absent unconditionally so nothing can end up loading
    # it by mistake, regardless of whether nftables itself is enabled.
    file { '/etc/nftables.conf':
        ensure => absent,
    }

    file { '/etc/nftables':
        ensure  => directory,
        recurse => true,
    }

    # each of these holds puppet-managed fragments. input/output/prerouting
    # get included by the matching chain in the base table, see
    # base::firewall. notrack fragments land directly in whichever of
    # those chains they need to affect (see nftables::service and
    # nftables::client) rather than a separate notrack directory, since a
    # service needs its notrack rule in prerouting while a client needs
    # its matching rule in output, and putting both cases in one shared
    # directory made it easy to only wire up half of that. sets holds
    # named address sets declared with nftables::set, referenced from
    # rules elsewhere with @setname.
    ['input', 'output', 'prerouting', 'sets'].each |$dir| {
        file { "/etc/nftables/${dir}":
            ensure  => directory,
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
