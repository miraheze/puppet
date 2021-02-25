# class base::dns
class base::dns {
    package { 'pdns-recursor':
        ensure => present,
    }

    file { '/etc/powerdns/recursor.conf':
        mode   => '0444',
        owner  => 'pdns',
        group  => 'pdns',
        source => 'puppet:///modules/base/dns/recursor.conf',
    }

}
