# class base::dns
class base::dns {
    package { 'pdns-recursor':
        ensure => present,
    }

    if $facts['processors']['count'] < 4 {
        $threads = 4
    } else {
        $threads = $facts['processors']['count']
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
        command  => '/usr/lib/nagios/plugins/check_dns -s ::1 -H miraheze.org',
        docs     => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#PowerDNS_Recursor',
        critical => true
    }

    file { '/etc/resolv.conf':
        content => template('base/dns/resolv.conf.erb'),
        require => Package['pdns-recursor'],
    }
}
