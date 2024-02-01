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

    systemd::unit { 'squid':
        content  => "[Service]\nLimitNOFILE=32768\n",
        override => true,
        restart  => true,
        require  => File['/etc/squid/squid.conf'],
    }
    service { 'squid':
        ensure    => 'running',
        require   => Systemd::Unit['squid'],
        subscribe => File['/etc/squid/squid.conf'],
    }
}
