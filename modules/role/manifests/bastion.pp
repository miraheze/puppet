class role::bastion (
    Boolean $bots_udp_proxy = false,
    Boolean $graylog_tcp_proxy = false,
    Boolean $webproxy_gateway = false,
    Boolean $monitoring_gateway = false,
    Array[Stdlib::Port] $monitoring_tcp_ports = [22, 53, 80, 443, 5666],
    Array[Stdlib::Port] $monitoring_udp_ports = [53],
) {
    include base
    include squid

    system::role { 'bastion':
        description => 'core access bastion host'
    }

    firewall::service { 'bastion-ssh-public':
        proto => 'tcp',
        port  => 22,
    }

    $squid_access_hosts_str = vmlib::generate_firewall_ip()

    # Add entire 10.0.0.0/8 (internal network) range and
    # remove individual private IPs.
    $squid_access_hosts_internal = join(
        (
            split($squid_access_hosts_str, ' ')
                .filter |$ip| { $ip !~ /^10\./ } + ['10.0.0.0/8']
        )
        .unique()
        .sort(),
        ' '
    )

    firewall::service { 'bastion-squid':
        proto  => 'tcp',
        port   => 8080,
        srange => "(${squid_access_hosts_internal})",
    }

    if $webproxy_gateway {
        $webproxy_clients_query = @("PQL")
            (resources { type = 'Class' and title = 'Role::Mediawiki' } or
            resources { type = 'Class' and title = 'Role::Mediawiki_task' } or
            resources { type = 'Class' and title = 'Role::Mediawiki_beta' })
            | PQL
        $webproxy_clients = split(vmlib::generate_firewall_ip($webproxy_clients_query), ' ')
            .filter |$ip| { $ip != '' }

        # Icinga only opens a TCP connection for the port check, so it needs
        # the firewall rule but not an nginx allow entry.
        $webproxy_monitoring_query = @("PQL")
            resources { type = 'Class' and title = 'Role::Icinga2' }
            | PQL
        $webproxy_monitoring = split(vmlib::generate_firewall_ip($webproxy_monitoring_query), ' ')
            .filter |$ip| { $ip != '' }

        $webproxy_srange = join(($webproxy_clients + $webproxy_monitoring).unique().sort(), ' ')

        class { 'webproxy::gateway':
            srange => "(${webproxy_srange})",
            allow  => ['127.0.0.1'] + $webproxy_clients,
        }
    }

    if $bots_udp_proxy or $graylog_tcp_proxy {
        $public_proxy_query = @("PQL")
            resources { type = 'Class' and title = 'Base' }
            | PQL
        # Allow those that don't have private IPs at all
        $public_proxy_clients = join(
            puppetdb::query_facts(['networking'], $public_proxy_query).values
                .filter |$node_facts| {
                    $ifaces = $node_facts['networking']['interfaces']
                    !$ifaces['vmbr1'] and !$ifaces['ens19']
                }
                .map |$node_facts| {
                    $net = $node_facts['networking']
                    if $net['interfaces']['ens18'] {
                        "${net['interfaces']['ens18']['ip']} ${net['interfaces']['ens18']['ip6']}"
                    } else {
                        "${net['ip']} ${net['ip6']}"
                    }
                }
                .flatten.sort.unique,
            ' '
        )
    }

    if $bots_udp_proxy {
        systemd::service { 'bots-udp-proxy':
            ensure  => present,
            restart => true,
            content => epp('role/bastion/bots-udp-proxy.service.epp'),
        }

        if $public_proxy_clients != '' {
            firewall::service { 'bastion-bots-udp':
                proto  => 'udp',
                port   => 5071,
                srange => "(${public_proxy_clients})",
            }
        }
    }

    if $graylog_tcp_proxy {
        systemd::service { 'graylog-tcp-proxy':
            ensure  => present,
            restart => true,
            content => epp('role/bastion/graylog-tcp-proxy.service.epp'),
        }

        if $public_proxy_clients != '' {
            firewall::service { 'bastion-graylog-tcp':
                proto  => 'tcp',
                port   => 12210,
                srange => "(${public_proxy_clients})",
            }
        }
    }

    if $monitoring_gateway {
        $monitoring_query = @("PQL")
            resources { type = 'Class' and title = 'Role::Icinga2' }
            | PQL
        $monitoring_sources = split(vmlib::generate_firewall_ip($monitoring_query), ' ')
            .filter |$ip| { $ip =~ /^10\./ }
            .sort.unique
        $monitoring_targets = vmlib::public_only_ipv4()

        if !$monitoring_sources.empty and !$monitoring_targets.empty {
            sysctl::parameters { 'bastion_ip_forward':
                values => { 'net.ipv4.ip_forward' => 1 },
            }

            $monitoring_source_set = $monitoring_sources.join(', ')
            $monitoring_target_set = $monitoring_targets.join(', ')
            $monitoring_tcp_set = $monitoring_tcp_ports.join(', ')
            $monitoring_udp_set = $monitoring_udp_ports.join(', ')

            nftables::file { 'monitoring-gateway':
                order   => 200,
                content => @("RULES")
                    table ip monitoring_gateway {
                        chain forward {
                            type filter hook forward priority 0; policy drop;
                            ct state established,related accept
                            ip saddr { ${monitoring_source_set} } ip daddr { ${monitoring_target_set} } tcp dport { ${monitoring_tcp_set} } ct state new accept
                            ip saddr { ${monitoring_source_set} } ip daddr { ${monitoring_target_set} } udp dport { ${monitoring_udp_set} } ct state new accept
                            ip saddr { ${monitoring_source_set} } ip daddr { ${monitoring_target_set} } icmp type echo-request accept
                        }

                        chain postrouting {
                            type nat hook postrouting priority 100;
                            ip saddr { ${monitoring_source_set} } ip daddr { ${monitoring_target_set} } masquerade
                        }
                    }
                    | RULES
            }
        }
    }

    firewall::service { 'bastion-ntp':
        proto  => 'udp',
        port   => 123,
        srange => '10.0.0.0/8',
    }

    # TCP passthrough for SMTP so fully private hosts can still reach
    # Google's SMTP relay. Google authorizes by source IP, so only the
    # bastion's public IP needs to be allowlisted in the Workspace admin
    # console. TLS stays wrapped end to end between the client and Google,
    # this box never terminates it or sees credentials.
    stdlib::ensure_packages('socat')

    systemd::service { 'smtp-relay-proxy':
        ensure  => present,
        restart => true,
        content => epp('role/bastion/smtp-relay-proxy.service.epp'),
    }

    firewall::service { 'bastion-smtp-relay':
        proto  => 'tcp',
        port   => 465,
        srange => "(${squid_access_hosts_internal})",
    }
}
