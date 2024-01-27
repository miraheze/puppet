# firewall for all servers
class base::firewall {
    include ferm
    # Increase the size of conntrack table size (default is 65536)
    sysctl::parameters { 'ferm_conntrack':
        values => {
            'net.netfilter.nf_conntrack_max'                   => 262144,
            'net.netfilter.nf_conntrack_tcp_timeout_time_wait' => 65,
        },
    }

    # The sysctl value net.netfilter.nf_conntrack_buckets is read-only. It is configured
    # via a modprobe parameter, bump it manually for running systems
    exec { 'bump nf_conntrack hash table size':
        command => '/bin/echo 32768 > /sys/module/nf_conntrack/parameters/hashsize',
        onlyif  => "/bin/grep --invert-match --quiet '^32768$' /sys/module/nf_conntrack/parameters/hashsize",
    }

    $block_abuse = split(file('/etc/puppetlabs/puppet/private/files/firewall/block_abuse'), /[\r\n]/)

    if $block_abuse != undef and $block_abuse != [] {
        ferm::rule { 'drop-abuse-net-miaheze':
            prio => '01',
            rule => "saddr (${$block_abuse.join(' ')}) DROP;",
        }
    }

    ferm::conf { 'main':
        prio   => '02',
        source => 'puppet:///modules/base/firewall/main-input-default-drop.conf',
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Icinga2]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'nrpe':
        proto  => 'tcp',
        port   => '5666',
        srange => "(${firewall_rules_str})",
    }

    $firewall_bastion_hosts = join(
        query_facts('Class[Base]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'ssh':
        proto  => 'tcp',
        port   => '22',
        srange => "(${firewall_bastion_hosts})",
    }

    class { '::ulogd': }

    # Explicitly drop pxe/dhcp packets packets so they dont hit the log
    ferm::filter_log { 'filter-bootp':
        proto => 'udp',
        daddr => '255.255.255.255',
        sport => 67,
        dport => 68,
    }

    ferm::rule { 'log-everything':
        rule => "NFLOG mod limit limit 1/second limit-burst 5 nflog-prefix \"[fw-in-drop]\";",
        prio => '98',
    }

    file { '/usr/lib/nagios/plugins/check_conntrack':
        source => 'puppet:///modules/base/firewall/check_conntrack.py',
        mode   => '0755',
    }

    monitoring::nrpe { 'conntrack_table_size':
        command => '/usr/lib/nagios/plugins/check_conntrack 80 90',
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#Conntrack_Table'
    }

    sudo::user { 'nagios_check_ferm':
        user       => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_ferm' ],
        require    => File['/usr/lib/nagios/plugins/check_ferm'],
    }

    file { '/usr/lib/nagios/plugins/check_ferm':
        source => 'puppet:///modules/base/firewall/check_ferm',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    monitoring::nrpe { 'ferm_active':
        command  => '/usr/bin/sudo /usr/lib/nagios/plugins/check_ferm',
        docs     => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#Ferm',
        critical => true
    }
}
