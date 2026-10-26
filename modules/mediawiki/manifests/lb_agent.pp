# === Class mediawiki::lb_agent
class mediawiki::lb_agent (
    Stdlib::Port $port = lookup('mediawiki::lb_agent::port', {'default_value' => 9590}),
    Float $maxconn_overcommit = lookup('mediawiki::lb_agent::maxconn_overcommit', {'default_value' => 1.5}),
) {
    $cache_subquery = @("PQL")
    resources { type = 'Class' and title = 'Role::Cache::Cache' }
    | PQL
    $lb_count = max(1, puppetdb::query_facts(['networking'], $cache_subquery).keys().flatten.sort.unique.length)

    file { '/usr/local/bin/mw-lb-agent':
        ensure => present,
        source => 'puppet:///modules/mediawiki/lb_agent.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        notify => Service['mw-lb-agent'],
    }

    systemd::service { 'mw-lb-agent':
        ensure  => present,
        content => systemd_template('mw-lb-agent', {
            'port'               => $port,
            'lb_count'           => $lb_count,
            'maxconn_overcommit' => $maxconn_overcommit,
        }),
        restart => true,
        require => File['/usr/local/bin/mw-lb-agent'],
    }

    $subquery = @("PQL")
    (resources { type = 'Class' and title = 'Role::Cache::Cache' } or
    resources { type = 'Class' and title = 'Role::Icinga2' })
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)
    firewall::service { "mediawiki lb agent port ${port}":
        proto   => 'tcp',
        port    => $port,
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    monitoring::services { 'MediaWiki LB agent':
        check_command => 'tcp',
        vars          => {
            tcp_address => $facts['networking']['interfaces']['ens19']['ip'],
            tcp_port    => String($port),
        },
    }
}
