# == Class: cloud

class cloud (
    String                        $main_interface = 'eno0',
    Stdlib::IP::Address           $main_ip4_address,
    String                        $main_ip4_netmask,
    String                        $main_ip4_broadcast,
    String                        $main_ip4_gateway,
    Stdlib::IP::Address           $main_ip6_address,
    String                        $main_ip6_gateway,
    Optional[String]              $private_interface = undef,
    Optional[Stdlib::IP::Address] $private_ip = undef,
    Optional[String]              $private_netmask = undef,
) {

    package { 'cloud-init':
        ensure => absent,
    }

    file { '/etc/network/interfaces.d/50-cloud-init.cfg':
        ensure  => 'present',
        source  => 'puppet:///modules/cloud/cloudinit/50-cloud-init.cfg',
    }

    file { '/etc/network/interfaces':
        ensure  => present,
        content => template('cloud/network/interfaces.erb'),
    }

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

    package { ['proxmox-ve', 'open-iscsi']:
        ensure => present,
        require => Apt::Source['proxmox_apt']
    }

    # Only run on a weekday of our choice, and vary it between servers
    $dow = fqdn_rand(5, 'md_checkarray_dow') + 1
    # Only run within a specific (February compatible) day of month range
    $dom_start = fqdn_rand(28 - 7, 'md_checkarray_dom') + 1
    $dom_end = $dom_start + 7
    # Replace the default mdadm script from upstream with our own
    file { '/etc/cron.d/mdadm':
        ensure  => $cron_ensure,
        content => template('cloud/mdadm-cron.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
    }
    
    cloud::logging { 'pveproxy':
        file_source_options => [
            '/var/log/pveproxy/access.log',
            { 'flags' => 'no-parse' }
        ],
        program_name => 'pveproxy',
    }

    cloud::logging { 'pve-firewall':
        file_source_options => [
            '/var/log/pve-firewall.log',
            { 'flags' => 'no-parse' }
        ],
        program_name => 'pve-firewall',
    }

    logrotate::conf { 'pve':
        ensure => present,
        source => 'puppet:///modules/cloud/pve.logrotate.conf',
    }

    logrotate::conf { 'pve-firewall':
        ensure => present,
        source => 'puppet:///modules/cloud/pve-firewall.logrotate.conf',
    }

    monitoring::nrpe { 'SMART':
        command => '/usr/bin/sudo /usr/lib/nagios/plugins/check_smart -g /dev/sda -i cciss,[0-6] -l -s'
    }

    monitoring::nrpe { 'IPMI Sensors':
        command => '/usr/lib/nagios/plugins/check_ipmi_sensors --xT Memory'
    }
}
