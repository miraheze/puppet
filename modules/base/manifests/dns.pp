# class base::dns
class base::dns (
    Array[String] $query_local_address = [],
    Boolean       $do_ipv4             = false,
    Boolean       $do_ipv6             = false,
    Boolean       $forward_use_internal,
    Boolean       $recurse             = true,
    Array[String] $recursor_addresses  = [],
    Array[String] $listen_addresses    = ['127.0.0.1', '::1'],
    Array[String] $allow_from          = ['127.0.0.0/8', '10.0.0.0/8', '::1/128'],
    String        $monitor_address     = '127.0.0.1',
) {
    stdlib::ensure_packages('pdns-recursor')

    if $facts['processors']['count'] < 4 {
        $threads = 4
    } else {
        $threads = $facts['processors']['count']
    }

    if $forward_use_internal {
        $forward_addresses = ['10.0.17.171']
    } else {
        $forward_addresses = ['2602:294:0:b23::111', '2001:41d0:801:2000::4089']
    }

    $zone_forwards = {
        'wtnet'           => $forward_addresses,
        '10.in-addr.arpa' => $forward_addresses,
        'wikitide.net'    => $forward_addresses,
    }

    $root_forward_addresses = $recursor_addresses.empty ? {
        true    => $forward_addresses,
        default => $recursor_addresses,
    }

    $forward_zones = $recurse ? {
        true    => $zone_forwards,
        default => $zone_forwards + { '.' => $root_forward_addresses },
    }

    file { '/etc/powerdns/recursor.yml':
        mode    => '0444',
        owner   => 'pdns',
        group   => 'pdns',
        notify  => Service['pdns-recursor'],
        content => template('base/dns/recursor.yml.erb'),
    }

    systemd::service { 'pdns-recursor':
        ensure   => present,
        override => true,
        restart  => true,
        content  => template('base/dns/override.conf.erb'),
        require  => [
          Package['pdns-recursor'],
          File['/etc/powerdns/recursor.yml']
        ],
    }

    monitoring::nrpe { 'PowerDNS Recursor':
        command  => "/usr/lib/nagios/plugins/check_dns -s ${monitor_address} -H ${facts['networking']['fqdn']}",
        docs     => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#PowerDNS_Recursor',
        critical => true
    }

    file { '/etc/resolv.conf':
        content => template('base/dns/resolv.conf.erb'),
        require => Package['pdns-recursor'],
    }
}
