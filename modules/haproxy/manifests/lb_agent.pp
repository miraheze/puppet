# === Class haproxy::lb_agent
#
# Reports weight and maxconn of a backend to the HAProxy load balancer pools.
# To remove it from a host, set lb_agent: false for the server in the
# balancer hiera first, then set ensure to absent.
class haproxy::lb_agent (
    VMlib::Ensure $ensure = lookup('haproxy::lb_agent::ensure', {'default_value' => present}),
    Stdlib::Port $port = lookup('haproxy::lb_agent::port', {'default_value' => 9590}),
    Float $maxconn_overcommit = lookup('haproxy::lb_agent::maxconn_overcommit', {'default_value' => 1.5}),
) {
    if $ensure == present {
        $cache_subquery = @("PQL")
        resources { type = 'Class' and title = 'Role::Cache::Cache' }
        | PQL
        $lb_count = max(1, puppetdb::query_facts(['networking'], $cache_subquery).keys().flatten.sort.unique.length)

        $subquery = @("PQL")
        (resources { type = 'Class' and title = 'Role::Cache::Cache' } or
        resources { type = 'Class' and title = 'Role::Icinga2' })
        | PQL
        $firewall_rules_str = vmlib::generate_firewall_ip($subquery)

        $service_content = systemd_template('lb-agent', {
            'port'               => $port,
            'lb_count'           => $lb_count,
            'maxconn_overcommit' => $maxconn_overcommit,
        })

        File['/usr/local/bin/lb-agent'] -> Systemd::Service['lb-agent']
        File['/usr/local/bin/lb-agent'] ~> Service['lb-agent']
    } else {
        $firewall_rules_str = undef
        $service_content = ''

        Systemd::Service['lb-agent'] -> File['/usr/local/bin/lb-agent']
    }

    file { '/usr/local/bin/lb-agent':
        ensure => stdlib::ensure($ensure, 'file'),
        source => 'puppet:///modules/haproxy/lb_agent.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    systemd::service { 'lb-agent':
        ensure  => $ensure,
        content => $service_content,
        restart => true,
    }

    firewall::service { "lb agent port ${port}":
        ensure  => $ensure,
        proto   => 'tcp',
        port    => $port,
        srange  => $firewall_rules_str ? {
            undef   => undef,
            default => "(${firewall_rules_str})",
        },
        notrack => true,
    }

    $address = $facts['networking']['interfaces']['ens19'] ? {
        undef   => $facts['networking']['ip'],
        default => $facts['networking']['interfaces']['ens19']['ip'],
    }

    monitoring::services { 'LB agent':
        ensure        => $ensure,
        check_command => 'tcp',
        vars          => {
            tcp_address => $address,
            tcp_port    => String($port),
        },
    }

    # TODO: remove once puppet runs
    systemd::service { 'mw-lb-agent':
        ensure  => absent,
        content => '',
        before  => Systemd::Service['lb-agent'],
    }

    file { '/usr/local/bin/mw-lb-agent':
        ensure  => absent,
        require => Systemd::Service['mw-lb-agent'],
    }

    firewall::service { "mediawiki lb agent port ${port}":
        ensure => absent,
        proto  => 'tcp',
        port   => $port,
    }

    monitoring::services { 'MediaWiki LB agent':
        ensure        => absent,
        check_command => 'tcp',
    }
}
