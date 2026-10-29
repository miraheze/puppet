# class base::dns
class base::dns (
    Array[String]    $query_local_address = [],
    Boolean          $do_ipv4             = false,
    Boolean          $do_ipv6             = false,
    Boolean          $forward_use_internal,
    Boolean          $recurse             = true,
    Array[String]    $recursor_addresses  = [],
    Array[String]    $resolvers           = [],
    Array[String]    $listen_addresses    = ['127.0.0.1', '::1'],
    Array[String]    $allow_from          = ['127.0.0.0/8', '10.0.0.0/8', '::1/128'],
    Integer          $listen_port         = 53,
    String           $monitor_address     = '127.0.0.1',
    Array[String]    $internal_zone_names = ['wtnet', '10.in-addr.arpa'],
    Array[String]    $forward_zone_names  = ['wikitide.net'],
    Boolean          $smtp_relay_override = true,
    String           $smtp_relay_bastion  = 'bastion.fsslc.wtnet',
    Optional[String] $smtp_relay_ip       = undef,
) {
    stdlib::ensure_packages('pdns-recursor')

    if $facts['processors']['count'] < 4 {
        $threads = 4
    } else {
        $threads = $facts['processors']['count']
    }

    $internal_addresses = ['10.0.17.171']

    $ifaces = $facts['networking']['interfaces']
    $has_private_net = ($ifaces['ens19'] != undef or $ifaces['vmbr1'] != undef)

    if $forward_use_internal {
        $forward_addresses = $internal_addresses
    } else {
        $forward_addresses = ['2602:294:0:b23::111', '2604:2dc0:121::1153']
    }

    $internal_zone_addresses = $has_private_net ? {
        true    => $internal_addresses,
        default => $forward_addresses,
    }

    $internal_zone_forwards = $internal_zone_names.reduce({}) |$memo, $zone| {
        $memo + { $zone => $internal_zone_addresses }
    }

    $public_zone_forwards = $forward_zone_names.reduce({}) |$memo, $zone| {
        $memo + { $zone => $forward_addresses }
    }

    $zone_forwards = $internal_zone_forwards + $public_zone_forwards

    $root_forward_addresses = $recursor_addresses.empty ? {
        true    => $forward_addresses,
        default => $recursor_addresses,
    }

    $forward_zones_recurse = $recurse ? {
        true    => {},
        default => { '.' => $root_forward_addresses },
    }

    file { '/etc/powerdns/recursor.yml':
        mode    => '0444',
        owner   => 'pdns',
        group   => 'pdns',
        notify  => Service['pdns-recursor'],
        content => template('base/dns/recursor.yml.erb'),
    }

    # Answers smtp-relay.gmail.com locally with the bastion address. Never set on the bastion itself.
    if $smtp_relay_override {
        $smtp_relay_address = $smtp_relay_ip ? {
            undef   => ipresolve($smtp_relay_bastion, 4),
            default => $smtp_relay_ip,
        }

        file { '/etc/powerdns/smtp-relay.gmail.com.zone':
            mode    => '0444',
            owner   => 'pdns',
            group   => 'pdns',
            notify  => Service['pdns-recursor'],
            content => epp('base/dns/smtp-relay.zone.epp', { 'address' => $smtp_relay_address }),
        }
    } else {
        file { '/etc/powerdns/smtp-relay.gmail.com.zone':
            ensure => absent,
            notify => Service['pdns-recursor'],
        }
    }

    systemd::service { 'pdns-recursor':
        ensure   => present,
        override => true,
        restart  => true,
        content  => epp('base/dns/override.conf.epp'),
        require  => [
          Package['pdns-recursor'],
          File['/etc/powerdns/recursor.yml']
        ],
    }

    $recursor_check = $listen_port ? {
        53      => "/usr/lib/nagios/plugins/check_dns -s ${monitor_address} -H ${facts['networking']['fqdn']}",
        default => "/usr/bin/dig +time=2 +tries=1 @${monitor_address} -p ${listen_port} ${facts['networking']['fqdn']} A",
    }

    monitoring::nrpe { 'PowerDNS Recursor':
        command  => $recursor_check,
        docs     => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#PowerDNS_Recursor',
        critical => true
    }

    if $listen_port != 53 {
        firewall::service { 'pdns-recursor-alt-port-udp':
            proto   => 'udp',
            notrack => true,
            prio    => 5,
            port    => $listen_port,
            srange  => $allow_from,
        }

        firewall::service { 'pdns-recursor-alt-port-tcp':
            proto   => 'tcp',
            notrack => true,
            prio    => 5,
            port    => $listen_port,
            srange  => $allow_from,
        }
    }

    file { '/etc/resolv.conf':
        content => template('base/dns/resolv.conf.erb'),
        require => Package['pdns-recursor'],
    }
}
