# ferm is a frontend for iptables
# https://wiki.debian.org/ferm
#
# @param ensure present installs and enables ferm. absent purges it.
class ferm (
    VMlib::Ensure $ensure = 'present',
) {
    # @resolve requires libnet-dns-perl

    file { '/etc/modprobe.d/nf_conntrack.conf':
        ensure => stdlib::ensure($ensure, 'file'),
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        source => 'puppet:///modules/base/firewall/nf_conntrack.conf',
    }

    # The nf_conntrack kernel module is usually auto-loaded during ferm startup.
    # But some additional configuration options for timewait handling are configured
    #   via sysctl settings and if ferm autoloads the kernel module after
    #   systemd-sysctl.service has run, the sysctl settings are not applied.
    # Add the nf_conntrack module via /etc/modules-load.d/ which loads
    #   them before systemd-sysctl.service is executed.
    file { '/etc/modules-load.d/conntrack.conf':
        ensure  => stdlib::ensure($ensure, 'file'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => "nf_conntrack\n",
        require => File['/etc/modprobe.d/nf_conntrack.conf'],
        before  => Package['ferm', 'libnet-dns-perl', 'conntrack'],
    }

    if $ensure == 'present' {
        stdlib::ensure_packages(['ferm', 'libnet-dns-perl', 'conntrack'])
    } else {
        stdlib::ensure_packages(['libnet-dns-perl', 'conntrack'])
        stdlib::ensure_packages(['ferm'], { 'ensure' => 'purged' })
    }

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
        require => Package['ferm'],
    }

    file { '/etc/ferm/functions.conf' :
        ensure  => stdlib::ensure($ensure, 'file'),
        owner   => 'root',
        group   => 'root',
        mode    => '0400',
        source  => 'puppet:///modules/ferm/functions.conf',
        require => Package['ferm'],
    }

    file { '/etc/ferm/conf.d' :
        ensure  => stdlib::ensure($ensure, 'directory'),
        owner   => 'root',
        group   => 'adm',
        mode    => '0500',
        recurse => true,
        purge   => true,
        require => Package['ferm'],
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
            path => '/usr/sbin/iptables-legacy',
        }

        alternatives::select { 'ip6tables':
            path => '/usr/sbin/ip6tables-legacy',
        }

        # the rules are virtual resources for cases where they are defined in a
        # class but the host doesn't have ferm enabled
        File <| tag == 'ferm' |>
    } else {
        exec { 'revert iptables alternative to auto':
            command => '/usr/bin/update-alternatives --auto iptables',
            unless  => "/usr/bin/update-alternatives --query iptables | /bin/grep -q 'Status: auto'",
        }

        exec { 'revert ip6tables alternative to auto':
            command => '/usr/bin/update-alternatives --auto ip6tables',
            unless  => "/usr/bin/update-alternatives --query ip6tables | /bin/grep -q 'Status: auto'",
        }
    }
}
