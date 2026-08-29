# firewall for all servers
class base::firewall (
    Firewall::Provider $provider = lookup('base::firewall::provider', { 'default_value' => 'nftables' }),
) {
    class { 'firewall':
        provider => $provider,
    }

    $nftables_active = $provider in ['nftables', 'both']

    sysctl::parameters { 'nftables_conntrack':
        ensure => $nftables_active ? { true => 'present', default => 'absent' },
        values => {
            'net.netfilter.nf_conntrack_max'                   => 262144,
            'net.netfilter.nf_conntrack_tcp_timeout_time_wait' => 65,
        },
    }

    stdlib::ensure_packages('conntrack')

    file { '/etc/modprobe.d/nf_conntrack.conf':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        source => 'puppet:///modules/base/firewall/nf_conntrack.conf',
    }

    # The nf_conntrack kernel module is usually auto-loaded during firewall startup.
    # But some additional configuration options for timewait handling are configured
    #   via sysctl settings and if the firewall autoloads the kernel module after
    #   systemd-sysctl.service has run, the sysctl settings are not applied.
    # Add the nf_conntrack module via /etc/modules-load.d/ which loads
    #   them before systemd-sysctl.service is executed.
    file { '/etc/modules-load.d/conntrack.conf':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => "nf_conntrack\n",
        require => File['/etc/modprobe.d/nf_conntrack.conf'],
        before  => Package['conntrack'],
    }

    # The sysctl value net.netfilter.nf_conntrack_buckets is read-only. It is configured
    # via a modprobe parameter, bump it manually for running systems
    exec { 'bump nf_conntrack hash table size':
        command => '/bin/echo 32768 > /sys/module/nf_conntrack/parameters/hashsize',
        onlyif  => "/bin/grep --invert-match --quiet '^32768$' /sys/module/nf_conntrack/parameters/hashsize",
    }

    $block_abuse = split(file('/etc/puppetlabs/puppet/private/files/firewall/block_abuse'), /[\r\n]/)

    if $block_abuse != undef and $block_abuse != [] {
        $block_abuse_v4 = $block_abuse.filter |$ip| { $ip =~ Stdlib::IP::Address::V4 }
        $block_abuse_v6 = $block_abuse.filter |$ip| { $ip =~ Stdlib::IP::Address::V6 }

        nftables::set { 'ABUSE_NETS':
            ips => $block_abuse,
        }

        # nftables::set only creates a family's set file if that family
        # actually has members, even when declared overall, so a line
        # here referencing an empty family's set would fail to load -
        # only including the lines that have somewhere to point avoids
        # that.
        $block_abuse_lines = ($block_abuse_v4.empty ? { true => [], default => ['ip saddr @ABUSE_NETS_ipv4 drop'] }) +
        ($block_abuse_v6.empty ? { true => [], default => ['ip6 saddr @ABUSE_NETS_ipv6 drop'] })

        $joined_block_abuse_lines = $block_abuse_lines.join("\n")

        nftables::file::input { 'drop-abuse-nets':
            order   => 1,
            content => @("CONTENT"/L)
                ${joined_block_abuse_lines}
                | CONTENT
        }
    }

    # the base ruleset itself: default-drop on input, established/related,
    # loopback, multicast and icmp always allowed. deployed for both
    # backends unconditionally, same as everything else here, since it's
    # only realized on a host that actually has that backend installed.
    nftables::file { 'base':
        order   => 100,
        content => file('base/firewall/nftables-base.nft'),
    }

    firewall::service { 'nrpe':
        proto    => 'tcp',
        port     => 5666,
        src_sets => ['ICINGA2_HOSTS'],
    }

    firewall::service { 'ssh':
        proto    => 'tcp',
        port     => 22,
        src_sets => ['ALL_HOSTS'],
    }

    class { '::ulogd': }

    # Explicitly drop pxe/dhcp packets packets so they dont hit the log
    nftables::rules { 'filter_log_filter-bootp':
        prio  => 90,
        chain => 'input',
        rules => ['ip daddr 255.255.255.255 udp sport 67 udp dport 68 drop'],
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

    sudo::user { 'nagios_check_nftables':
        ensure     => $nftables_active ? { true => 'present', default => 'absent' },
        user       => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_nftables' ],
        require    => File['/usr/lib/nagios/plugins/check_nftables'],
    }

    file { '/usr/lib/nagios/plugins/check_nftables':
        ensure => stdlib::ensure($nftables_active, 'file'),
        source => 'puppet:///modules/base/firewall/check_nftables',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    monitoring::nrpe { 'nftables_active':
        ensure   => $nftables_active ? { true => 'present', default => 'absent' },
        command  => '/usr/bin/sudo /usr/lib/nagios/plugins/check_nftables',
        docs     => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#Nftables',
        critical => true
    }
}
