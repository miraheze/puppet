# class squid
class squid (
    Integer $connect_timeout      = 5,
    Integer $peer_connect_timeout = 5,
    Integer $forward_timeout      = 15,
    Integer $forward_max_tries    = 2,
    Integer $dns_timeout          = 3,
    Integer $read_timeout         = 30,
    Integer $request_timeout      = 30,
    Integer $client_lifetime      = 300,
    Integer $quick_abort_min      = 0,
    Integer $quick_abort_max      = 0,
    Integer $read_ahead_gap       = 1024,
) {
    package { 'squid':
        ensure => present,
    }

    file { '/etc/squid/squid.conf':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => epp('squid/squid.conf.epp', {
            'quick_abort_min'      => $quick_abort_min,
            'quick_abort_max'      => $quick_abort_max,
            'read_ahead_gap'       => $read_ahead_gap,
            'forward_timeout'      => $forward_timeout,
            'connect_timeout'      => $connect_timeout,
            'peer_connect_timeout' => $peer_connect_timeout,
            'forward_max_tries'    => $forward_max_tries,
            'dns_timeout'          => $dns_timeout,
            'read_timeout'         => $read_timeout,
            'request_timeout'      => $request_timeout,
            'client_lifetime'      => $client_lifetime,
        }),
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

    monitoring::services { 'squid':
        check_command => 'tcp',
        vars          => {
            tcp_port  => '8080',
        },
    }
}
