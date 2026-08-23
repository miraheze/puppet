# firewall for all servers
class base::firewall (
    Firewall::Provider $provider = lookup('base::firewall::provider', { 'default_value' => 'ferm' }),
) {
    class { 'firewall':
        provider => $provider,
    }

    $ferm_active     = $provider in ['ferm', 'both']
    $nftables_active = $provider in ['nftables', 'both']

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

        $block_abuse_v4 = $block_abuse.filter |$ip| { $ip !~ /:/ }
        $block_abuse_v6 = $block_abuse.filter |$ip| { $ip =~ /:/ }

        $block_abuse_nft = ($block_abuse_v4.empty ? { true => [], default => ["ip saddr { ${block_abuse_v4.join(', ')} } drop"] }) +
        ($block_abuse_v6.empty ? { true => [], default => ["ip6 saddr { ${block_abuse_v6.join(', ')} } drop"] })

        nftables::rules { 'drop-abuse-net-wikitide':
            prio  => 1,
            chain => 'input',
            rules => $block_abuse_nft,
        }
    }

    # the base ruleset itself: default-drop on input, established/related,
    # loopback, multicast and icmp always allowed. deployed for both
    # backends unconditionally, same as everything else here, since it's
    # only realized on a host that actually has that backend installed.
    ferm::conf { 'main':
        prio   => '02',
        source => 'puppet:///modules/base/firewall/main-input-default-drop.conf',
    }

    nftables::file { 'base':
        order   => 100,
        content => file('base/firewall/nftables-base.nft'),
    }

    $subquery = @("PQL")
    resources { type = 'Class' and title = 'Role::Icinga2' }
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)
    firewall::service { 'nrpe':
        proto  => 'tcp',
        port   => '5666',
        srange => "(${firewall_rules_str})",
    }

    $subquery_2 = @("PQL")
    resources { type = 'Class' and title = 'Base' }
    | PQL
    $firewall_bastion_hosts = vmlib::generate_firewall_ip($subquery_2)
    firewall::service { 'ssh':
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

    nftables::rules { 'filter-bootp':
        prio  => 90,
        chain => 'input',
        rules => ['udp ip daddr 255.255.255.255 sport 67 dport 68 drop'],
    }

    ferm::rule { 'log-everything':
        rule => "NFLOG mod limit limit 1/second limit-burst 5 nflog-prefix \"[fw-in-drop]\";",
        prio => '98',
    }

    nftables::rules { 'log-everything':
        prio  => 98,
        chain => 'input',
        rules => ['limit rate 1/second burst 5 packets log prefix "[fw-in-drop] " group 0'],
    }

    file { '/usr/lib/nagios/plugins/check_conntrack':
        source => 'puppet:///modules/base/firewall/check_conntrack.py',
        mode   => '0755',
    }

    monitoring::nrpe { 'conntrack_table_size':
        command => '/usr/lib/nagios/plugins/check_conntrack 80 90',
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#Conntrack_Table'
    }

    if $ferm_active {
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

    if $nftables_active {
        sudo::user { 'nagios_check_nftables':
            user       => 'nagios',
            privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_nftables' ],
            require    => File['/usr/lib/nagios/plugins/check_nftables'],
        }

        file { '/usr/lib/nagios/plugins/check_nftables':
            source => 'puppet:///modules/base/firewall/check_nftables',
            owner  => 'root',
            group  => 'root',
            mode   => '0555',
        }

        monitoring::nrpe { 'nftables_active':
            command  => '/usr/bin/sudo /usr/lib/nagios/plugins/check_nftables',
            docs     => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#Nftables',
            critical => true
        }
    }
}
