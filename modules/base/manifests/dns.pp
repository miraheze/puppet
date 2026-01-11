# class base::dns
class base::dns (
    Array[String] $query_local_address,
    Boolean       $forward_use_internal,
) {
    stdlib::ensure_packages('pdns-recursor')

    if $facts['processors']['count'] < 4 {
        $threads = 4
    } else {
        $threads = $facts['processors']['count']
    }

    if $forward_use_internal {
        # Get rid when we no longer use debian bookworm
        $forward_zones = 'wtnet=10.0.17.171, 10.in-addr.arpa=10.0.17.171, wikitide.net=10.0.17.171'
        # For debian trixie+
        $forward_zones_new = {
            'wtnet'          => ['10.0.17.171'],
            '10.in-addr.arpa'=> ['10.0.17.171'],
            'wikitide.net'   => ['10.0.17.171'],
        }
        $local_address = '127.0.0.1'
    } else {
        # Get rid when we no longer use debian bookworm
        $forward_zones = 'wtnet=2602:294:0:b23::111;2001:41d0:801:2000::4089, 10.in-addr.arpa=2602:294:0:b23::111;2001:41d0:801:2000::4089, wikitide.net=2602:294:0:b23::111;2001:41d0:801:2000::4089'
        # For debian trixie+
        $forward_zones_new = {
            'wtnet'          => ['2602:294:0:b23::111', '2001:41d0:801:2000::4089'],
            '10.in-addr.arpa'=> ['2602:294:0:b23::111', '2001:41d0:801:2000::4089'],
            'wikitide.net'   => ['2602:294:0:b23::111', '2001:41d0:801:2000::4089'],
        }
        $local_address = '::1'
    }

    if (versioncmp($facts['os']['release']['major'], '13') >= 0) {
        $file_ext = 'yml'
    } else {
        $file_ext = 'conf'
    }

    file { "/etc/powerdns/recursor.${file_ext}":
        mode    => '0444',
        owner   => 'pdns',
        group   => 'pdns',
        notify  => Service['pdns-recursor'],
        content => template("base/dns/recursor.${file_ext}.erb"),
    }

    systemd::service { 'pdns-recursor':
        ensure   => present,
        override => true,
        restart  => true,
        content  => template('base/dns/override.conf.erb'),
        require  => [
          Package['pdns-recursor'],
          File["/etc/powerdns/recursor.${file_ext}"]
        ],
    }

    monitoring::nrpe { 'PowerDNS Recursor':
        command  => "/usr/lib/nagios/plugins/check_dns -s ${local_address} -H ${facts['networking']['fqdn']}",
        docs     => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#PowerDNS_Recursor',
        critical => true
    }

    file { '/etc/resolv.conf':
        content => template('base/dns/resolv.conf.erb'),
        require => Package['pdns-recursor'],
    }
}
