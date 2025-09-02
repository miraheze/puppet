# class base::dns
class base::dns (
    Array[String] $query_local_address,
    Boolean       $forward_use_internal,
) {
    package { 'pdns-recursor':
        ensure => present,
    }

    if $facts['processors']['count'] < 4 {
        $threads = 4
    } else {
        $threads = $facts['processors']['count']
    }

    if $forward_use_internal {
        $forward_zones = 'wtnet=10.0.17.136, 10.in-addr.arpa=10.0.17.136, wikitide.net=10.0.17.136'
        $local_address = '127.0.0.1'
    } else {
        $forward_zones = 'wtnet=2602:294:0:b23::111;2001:41d0:801:2000::4089, 10.in-addr.arpa=2602:294:0:b23::111;2001:41d0:801:2000::4089, wikitide.net=2602:294:0:b23::111;2001:41d0:801:2000::4089'
        $local_address = '::1'
    }

    file { '/etc/powerdns/recursor.conf':
        mode    => '0444',
        owner   => 'pdns',
        group   => 'pdns',
        notify  => Service['pdns-recursor'],
        content => template('base/dns/recursor.conf.erb'),
    }

    systemd::service { 'pdns-recursor':
        ensure   => present,
        override => true,
        restart  => true,
        content  => template('base/dns/override.conf.erb'),
        require  => [
          Package['pdns-recursor'],
          File['/etc/powerdns/recursor.conf']
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
