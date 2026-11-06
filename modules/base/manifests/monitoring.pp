# base::monitoring
class base::monitoring {
    include prometheus::exporter::node

    $nagios_packages = [ 'monitoring-plugins', 'monitoring-plugins-contrib', 'nagios-nrpe-server', ]
    package { $nagios_packages:
        ensure => present,
    }

    # Hosts without a private IP are checked through the bastion, so NRPE sees the bastion's address.
    if $facts['networking']['interfaces']['vmbr1'] or $facts['networking']['interfaces']['ens19'] {
        $bastion_hosts = []
    } else {
        $bastion_query = @("PQL")
            resources { type = 'Class' and title = 'Role::Bastion' }
            | PQL
        $bastion_hosts = split(vmlib::generate_firewall_ip($bastion_query), ' ')
            .filter |$ip| { $ip != '' and $ip !~ /^10\./ }
            .sort.unique
    }

    $allowed_hosts = (['127.0.0.1', '2602:294:0:b12::110', '10.0.18.109'] + $bastion_hosts).join(',')

    file { '/etc/nagios/nrpe.cfg':
        ensure  => present,
        content => epp('base/icinga/nrpe.cfg.epp', { 'allowed_hosts' => $allowed_hosts }),
        require => Package['nagios-nrpe-server'],
        notify  => Service['nagios-nrpe-server'],
    }

    file { '/usr/lib/nagios/plugins/check_puppet_run':
        ensure  => present,
        content => epp('base/icinga/check_puppet_run.epp'),
        mode    => '0555',
    }

    file { '/usr/lib/nagios/plugins/check_smart':
        ensure => present,
        source => 'puppet:///modules/base/icinga/check_smart',
        mode   => '0555',
    }

    file { '/usr/lib/nagios/plugins/check_ipmi_sensors':
        ensure => present,
        source => 'puppet:///modules/base/icinga/check_ipmi_sensors',
        mode   => '0555',
    }

    service { 'nagios-nrpe-server':
        ensure     => 'running',
        hasrestart => true,
    }

    # SUDO FOR NRPE
    sudo::user { 'nrpe_sudo':
        user       => 'nagios',
        privileges => [
            'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_gdnsd_datacenters',
            'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_puppet_run',
            'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_smart',
            'ALL = NOPASSWD: /usr/sbin/ipmi-dcmi',
            'ALL = NOPASSWD: /usr/sbin/ipmi-sel',
            'ALL = NOPASSWD: /usr/sbin/ipmi-sensors',
        ],
    }

    monitoring::hosts { $facts['networking']['hostname']: }

    monitoring::nrpe { 'Disk Space':
        command         => '/usr/lib/nagios/plugins/check_disk -w 10% -c 5% -p /',
        docs            => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#Disk_Space',
        critical        => true,
        phorge_triggers => [ 'CRITICAL' ],
        phorge_projects => [ 'tech-infra' ],
    }

    $load_critical = $facts['processors']['count'] * 2.0
    $load_warning = $facts['processors']['count'] * 1.7
    monitoring::nrpe { 'Current Load':
        command => "/usr/lib/nagios/plugins/check_load -w ${load_warning} -c ${load_critical}",
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#Current_Load',
    }

    monitoring::nrpe { 'Puppet':
        command => '/usr/bin/sudo /usr/lib/nagios/plugins/check_puppet_run -w 3600 -c 43200',
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#Puppet',
    }

    monitoring::services { 'SSH':
        check_command => 'ssh',
        docs          => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#SSH',
    }

    monitoring::nrpe { 'APT':
        command => '/usr/lib/nagios/plugins/check_apt -o -t 60',
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#APT',
    }

    monitoring::nrpe { 'chrony':
        command => '/usr/lib/nagios/plugins/check_chrony -w 50 -c 100 -W 5 -C 10',
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#Chrony',
    }

    # Collect all NRPE command files
    File <| tag == 'nrpe' |>
}
