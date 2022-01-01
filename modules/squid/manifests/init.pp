# clas squid
class squid {
    package { 'squid':
        ensure => present,
    }

    file { '/etc/squid/squid.conf':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/squid/squid.conf',
        require => Package['squid'],
    }

    service { 'squid':
        ensure    => 'running',
        require   => File['/etc/squid/squid.conf'],
        subscribe => File['/etc/squid/squid.conf'],
    }
}
