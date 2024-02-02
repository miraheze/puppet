# SPDX-License-Identifier: Apache-2.0
class strongswan (
    $puppet_certname = '',
    $hosts           = [],
    $mtu_hosts       = undef,
)
{
    package { 'strongswan':
        ensure => present,
    }

    # On Debian we need an extra package which is only "recommended"
    # rather than being a strict dependency.
    package { 'libstrongswan-standard-plugins':
        ensure  => present,
        before  => Service['strongswan'],
        require => Package['strongswan'],
    }

    file { '/etc/strongswan.d/miraheze.conf':
        content => template('strongswan/miraheze.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service['strongswan'],
        require => Package['strongswan'],
    }

    file { '/etc/ipsec.secrets':
        content => template('strongswan/ipsec.secrets.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0400',
        notify  => Service['strongswan'],
        require => Package['strongswan'],
    }

    file { '/etc/ipsec.conf':
        content => template('strongswan/ipsec.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service['strongswan'],
        require => Package['strongswan'],
    }

    # Strongswan won't accept symlinks, so make copies.
    file { '/etc/ipsec.d/cacerts/ca.pem':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
        notify  => Service['strongswan'],
        require => Package['strongswan'],
    }

    file { "/etc/ipsec.d/certs/${puppet_certname}.pem":
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => "/etc/puppetlabs/puppet/ssl/certs/${puppet_certname}.pem",
        notify  => Service['strongswan'],
        require => Package['strongswan'],
    }

    file { "/etc/ipsec.d/private/${puppet_certname}.pem":
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => "/etc/puppetlabs/puppet/ssl/private_keys/${puppet_certname}.pem",
        notify  => Service['strongswan'],
        require => Package['strongswan'],
    }

    file { '/usr/local/sbin/ipsec-global':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/strongswan/ipsec-global',
    }

    systemd::service { 'strongswan':
        content => systemd_template('strongswan'),
        restart => true,
        require => Package['strongswan'],
    }
}
