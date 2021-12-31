# class base::dns
class base::dns (
    Boolean $use_ipv6 = lookup('base::dns::use_ipv6', {'default_value' => false})
) {
    package { 'pdns-recursor':
        ensure => present,
    }

    file { '/etc/powerdns/recursor.conf':
        mode   => '0444',
        owner  => 'pdns',
        group  => 'pdns',
        notify => Service['pdns-recursor'],
        source => 'puppet:///modules/base/dns/recursor.conf',
    }

    service { 'pdns-recursor':
        ensure  => running,
        require => Package['pdns-recursor'],
    }

    monitoring::services { 'PowerDNS Recursor':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_pdns_recursor',
        },
    }

    file { '/etc/resolv.conf':
        content => template('base/dns/resolv.conf.erb'),
        require => Package['pdns-recursor'],
    }
}
