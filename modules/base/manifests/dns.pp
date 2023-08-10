# class base::dns
class base::dns {
    package { 'pdns-recursor':
        ensure => present,
    }

    if $facts['processors']['count'] < 4 {
        $threads = 4
    } elsif {
        $threads = $facts['processors']['count']
    }

    file { '/etc/powerdns/recursor.conf':
        mode   => '0444',
        owner  => 'pdns',
        group  => 'pdns',
        notify => Service['pdns-recursor'],
        source => template('base/dns/recursor.conf.erb'),
    }

    service { 'pdns-recursor':
        ensure  => running,
        require => Package['pdns-recursor'],
    }

    monitoring::nrpe { 'PowerDNS Recursor':
        command  => '/usr/lib/nagios/plugins/check_dns -s 127.0.0.1 -H miraheze.org',
        docs     => 'https://meta.miraheze.org/wiki/Tech:Icinga/Base_Monitoring#PowerDNS_Recursor',
        critical => true
    }

    file { '/etc/resolv.conf':
        content => template('base/dns/resolv.conf.erb'),
        require => Package['pdns-recursor'],
    }
}
