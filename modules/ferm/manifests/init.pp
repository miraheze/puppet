# ferm is a frontend for iptables
# https://wiki.debian.org/ferm
#
# @param ensure present installs and enables ferm. absent purges it.
class ferm (
    VMlib::Ensure $ensure = 'present',
) {
    # @resolve requires libnet-dns-perl
    if $ensure == 'present' {
        stdlib::ensure_packages(['ferm', 'libnet-dns-perl'])
    } else {
        stdlib::ensure_packages(['ferm', 'libnet-dns-perl'], { 'ensure' => 'purged' })
    }

    # package { 'iptables':
    #    ensure => stdlib::ensure($ensure, 'package'),
    # }

    file {'/usr/local/sbin/ferm-status':
        ensure  => stdlib::ensure($ensure, 'file'),
        mode    => '0550',
        owner   => 'root',
        group   => 'root',
        content => file('ferm/ferm_status.py')
    }

    service { 'ferm':
        ensure  => stdlib::ensure($ensure, 'service'),
        status  => '/usr/local/sbin/ferm-status',
        start   => '/bin/systemctl reload-or-restart ferm',
        require => [
            Package['ferm'],
            File['/usr/local/sbin/ferm-status'],
        ]
    }

    file { '/etc/ferm':
        ensure  => stdlib::ensure($ensure, 'directory'),
        force   => true,
        purge   => true,
        recurse => true,
        require => Package['ferm'],
    }

    file { '/etc/ferm/ferm.conf':
        ensure  => stdlib::ensure($ensure, 'file'),
        owner   => 'root',
        group   => 'root',
        mode    => '0400',
        source  => 'puppet:///modules/ferm/ferm.conf',
        require => File['/etc/ferm'],
    }

    file { '/etc/ferm/functions.conf' :
        ensure  => stdlib::ensure($ensure, 'file'),
        owner   => 'root',
        group   => 'root',
        mode    => '0400',
        source  => 'puppet:///modules/ferm/functions.conf',
        require => File['/etc/ferm'],
    }

    file { '/etc/ferm/conf.d' :
        ensure  => stdlib::ensure($ensure, 'directory'),
        owner   => 'root',
        group   => 'adm',
        mode    => '0500',
        recurse => true,
        purge   => true,
        require => File['/etc/ferm'],
    }

    file { '/etc/default/ferm' :
        ensure  => stdlib::ensure($ensure, 'file'),
        owner   => 'root',
        group   => 'root',
        mode    => '0400',
        source  => 'puppet:///modules/ferm/ferm.default',
        require => Package['ferm'],
    }

    if $ensure == 'present' {
        File['/etc/ferm/ferm.conf', '/etc/ferm/functions.conf', '/etc/ferm/conf.d', '/etc/default/ferm'] ~> Service['ferm']

        # Starting with Bullseye iptables default to the nft backend, but for ferm
        # we need the legacy backend
        alternatives::select { 'iptables':
            path    => '/usr/sbin/iptables-legacy',
            require => Package['iptables'],
        }

        alternatives::select { 'ip6tables':
            path    => '/usr/sbin/ip6tables-legacy',
            require => Package['iptables'],
        }

        # the rules are virtual resources for cases where they are defined in a
        # class but the host doesn't have ferm enabled
        File <| tag == 'ferm' |>
    }
}
