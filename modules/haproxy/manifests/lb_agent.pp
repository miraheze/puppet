# === Class haproxy::lb_agent
#
# Reports weight and maxconn of a backend to the HAProxy load balancer pools.
# To remove it from a host, set lb_agent: false for the server in the
# balancer hiera first, then set ensure to absent.
#
# balancers maps a balancer role class to how many pools it has that use this
# host. The total divides the maxconn this host reports, and the balancer
# hosts are allowed to connect to the agent port.
class haproxy::lb_agent (
    VMlib::Ensure $ensure = lookup('haproxy::lb_agent::ensure', {'default_value' => present}),
    Stdlib::Port $port = lookup('haproxy::lb_agent::port', {'default_value' => 9590}),
    Float $maxconn_overcommit = lookup('haproxy::lb_agent::maxconn_overcommit', {'default_value' => 1.5}),
    Hash[Pattern[/\ARole::[A-Za-z0-9_:]+\z/], Integer[1], 1] $balancers = lookup('haproxy::lb_agent::balancers', {'default_value' => {'Role::Cache::Cache' => 1}}),
) {
    if $ensure == present {
        $lb_count = max(1, $balancers.reduce(0) |$total, $balancer| {
            $nodes = puppetdb::query_facts(['networking'], "resources { type = 'Class' and title = '${balancer[0]}' }").keys().flatten.sort.unique.length
            $total + ($nodes * $balancer[1])
        })

        $clauses = ($balancers.keys + ['Role::Icinga2']).map |$class_name| {
            "resources { type = 'Class' and title = '${class_name}' }"
        }
        $firewall_rules_str = vmlib::generate_firewall_ip("(${clauses.join(' or ')})")

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
}
