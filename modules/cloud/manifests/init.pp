# == Class: cloud

class cloud {
    file { '/etc/apt/trusted.gpg.d/proxmox.gpg':
        ensure => present,
        source => 'puppet:///modules/cloud/key/proxmox.gpg',
    }

    apt::source { 'proxmox_apt':
        location => 'http://download.proxmox.com/debian/pve',
        release  => $::lsbdistcodename,
        repos    => 'pve-no-subscription',
        require  => File['/etc/apt/trusted.gpg.d/proxmox.gpg'],
        notify   => Exec['apt_update_proxmox'],
    }

    apt::pin { 'proxmox_pin':
        priority => 600,
        origin   => 'download.proxmox.com'
    }

    # First installs can trip without this
    exec {'apt_update_proxmox':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
        require     => Apt::Pin['proxmox_pin'],
    }

    package { ['proxmox-ve', 'open-iscsi']:
        ensure  => present,
        require => Apt::Source['proxmox_apt']
    }

    $syslog_daemon = lookup('base::syslog::syslog_daemon', {'default_value' => 'syslog_ng'})
    if $syslog_daemon == 'syslog_ng' {
        cloud::logging { 'pveproxy':
            file_source_options => [
                '/var/log/pveproxy/access.log',
                { 'flags' => 'no-parse' }
            ],
            program_name        => 'pveproxy',
        }

        cloud::logging { 'pve-firewall':
            file_source_options => [
                '/var/log/pve-firewall.log',
                { 'flags' => 'no-parse' }
            ],
            program_name        => 'pve-firewall',
        }
    } else {
        rsyslog::input::file { 'pveproxy':
            path              => '/var/log/pveproxy/access.log',
            syslog_tag_prefix => '',
            use_udp           => true,
        }

        rsyslog::input::file { 'pve-firewall':
            path              => '/var/log/pve-firewall.log',
            syslog_tag_prefix => '',
            use_udp           => true,
        }
    }

    logrotate::conf { 'pve':
        ensure => present,
        source => 'puppet:///modules/cloud/pve.logrotate.conf',
    }

    logrotate::conf { 'pve-firewall':
        ensure => present,
        source => 'puppet:///modules/cloud/pve-firewall.logrotate.conf',
    }

    ensure_packages(['freeipmi-tools'])

    if ( $facts['dmi']['manufacturer'] == 'HP' ) {
        monitoring::nrpe { 'IPMI Sensors':
            command => '/usr/lib/nagios/plugins/check_ipmi_sensors --xT Memory'
        }

        monitoring::nrpe { 'SMART':
            command => '/usr/bin/sudo /usr/lib/nagios/plugins/check_smart -g /dev/sda -i cciss,[0-6] -l -s'
        }
    } else {
        monitoring::nrpe { 'IPMI Sensors':
            command => '/usr/lib/nagios/plugins/check_ipmi_sensors --xT Drive_Slot,Entity_Presence'
        }
    }
}
