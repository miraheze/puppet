# class webproxy::gateway
class webproxy::gateway (
    String $srange,
    Stdlib::Port $port = 8081,
    Array[Stdlib::IP::Address] $allow = [],
    Hash[Pattern[/\A[a-z0-9_]+\z/], Struct[{
        host                    => Stdlib::Fqdn,
        path                    => Pattern[/\A\/[A-Za-z0-9._\/-]+\z/],
        Optional[required_args] => Hash[Pattern[/\A[a-z_]+\z/], Pattern[/\A[A-Za-z0-9_.-]+\z/]],
        Optional[fresh_ttl]     => Pattern[/\A\d+[smhd]\z/],
        Optional[stale_ttl]     => Pattern[/\A\d+[smhd]\z/],
        Optional[error_ttl]     => Pattern[/\A\d+[smhd]\z/],
        Optional[cache_size]    => Pattern[/\A\d+[kmg]\z/],
        Optional[zone_size]     => Pattern[/\A\d+[kmg]\z/],
    }]] $upstreams = {},
) {
    include nginx

    $defaults = {
        'required_args' => {},
        'fresh_ttl'     => '2d',
        'stale_ttl'     => '14d',
        'error_ttl'     => '1m',
        'cache_size'    => '20g',
        'zone_size'     => '256m',
    }

    $resolved = $upstreams.reduce({}) |$memo, $entry| {
        $memo + { $entry[0] => $defaults + $entry[1] }
    }

    file { ['/var/cache/nginx', '/var/cache/nginx/webproxy']:
        ensure  => directory,
        require => Package['nginx'],
    }

    $resolved.each |$name, $cfg| {
        file { "/var/cache/nginx/webproxy/${name}":
            ensure  => directory,
            owner   => 'www-data',
            group   => 'www-data',
            mode    => '0750',
            require => File['/var/cache/nginx/webproxy'],
            before  => Nginx::Site['webproxy-gateway'],
        }
    }

    nginx::site { 'webproxy-gateway':
        ensure  => present,
        monitor => false,
        content => epp('webproxy/gateway.conf.epp', {
            'port'      => $port,
            'allow'     => $allow,
            'upstreams' => $resolved,
        }),
    }

    firewall::service { 'webproxy-gateway':
        proto  => 'tcp',
        port   => $port,
        srange => $srange,
    }

    monitoring::services { 'webproxy-gateway':
        check_command => 'tcp',
        vars          => {
            tcp_port => $port,
        },
    }
}
