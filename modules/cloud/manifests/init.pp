# == Class: cloud

class cloud (
    Stdlib::IP::Address $main_ip4_address   = hiera('role::cloud::main_ip4_address'),
                        $main_ip4_netmask   = hiera('role::cloud::main_ip4_netmask'),
                        $main_ip4_broadcast = hiera('role::cloud::main_ip4_broadcast'),
                        $main_ip4_gateway   = hiera('role::cloud::main_ip4_gateway'),
    Stdlib::IP::Address $main_ip6_address   = hiera('role::cloud::main_ip6_address'),
                        $main_ip6_gateway   = hiera('role::cloud::main_ip6_gateway'),
) {

    file { '/etc/apt/trusted.gpg.d/proxmox.gpg':
        ensure => present,
        source => 'puppet:///modules/cloud/key/proxmox.gpg',
    }

    apt::source { 'proxmox_apt':
        location => 'http://download.proxmox.com/debian/pve',
        release  => "${::lsbdistcodename}",
        repos    => 'pve-no-subscription',
        require  => File['/etc/apt/trusted.gpg.d/proxmox.gpg'],
        notify   => Exec['apt_update_proxmox'],
    }

    apt::pin { 'proxmox_pin':
        priority        => 600,
        origin          => 'download.proxmox.com'
    }

    # First installs can trip without this
    exec {'apt_update_proxmox':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
        require     => Apt::Pin['proxmox_pin'],
    }

    require_package('proxmox-ve', 'open-iscsi')

    file { '/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg':
        ensure  => 'present',
        source  => 'puppet:///modules/cloud/cloudinit/99-disable-network-config.cfg',
    }

    file { '/etc/network/interfaces.d/50-cloud-init.cfg':
        ensure  => 'present',
        source  => 'puppet:///modules/cloud/cloudinit/50-cloud-init.cfg',
    }

    file { '/etc/network/interfaces':
        ensure  => present,
        content => template('cloud/network/interfaces.erb'),
    }
}
