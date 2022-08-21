# role: dns
class role::dns {
    include ::dns

    package { 'python3-dnspython':
        ensure => latest
    }

    ferm::service { 'dns_udp':
        proto => 'udp',
        port  => '53',
    }

    ferm::service { 'dns_tcp':
        proto => 'tcp',
        port  => '53',
    }

    ferm::rule { 'skip_dns_conntrack-out':
        desc  => 'Skip DNS outgoing connection tracking',
        table => 'raw',
        chain => 'OUTPUT',
        rule  => 'proto udp sport 53 NOTRACK;',
    }

    ferm::rule { 'skip_dns_conntrack-in':
        desc  => 'Skip DNS incoming connection tracking',
        table => 'raw',
        chain => 'PREROUTING',
        rule  => 'proto udp dport 53 NOTRACK;',
    }

    motd::role { 'role::dns':
        description => 'authoritative DNS server',
    }
}
