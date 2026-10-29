class role::bastion (
    Boolean $webproxy_gateway = false,
    Boolean $bots_udp_proxy = false,
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

    if $bots_udp_proxy {
        $bots_proxy_query = @("PQL")
            resources { type = 'Class' and title = 'Base' }
            | PQL
        # Allow those that don't have private IPs at all
        $bots_proxy_clients = join(
            puppetdb::query_facts(['networking'], $bots_proxy_query).values
                .filter |$facts| {
                    $ifaces = $facts['networking']['interfaces']
                    !$ifaces['vmbr1'] and !$ifaces['ens19']
                }
                .map |$facts| {
                    $net = $facts['networking']
                    if $net['interfaces']['ens18'] {
                        "${net['interfaces']['ens18']['ip']} ${net['interfaces']['ens18']['ip6']}"
                    } else {
                        "${net['ip']} ${net['ip6']}"
                    }
                }
                .flatten.sort.unique,
            ' '
        )

        systemd::service { 'bots-udp-proxy':
            ensure  => present,
            restart => true,
            content => epp('role/bastion/bots-udp-proxy.service.epp'),
        }

        if $bots_proxy_clients != '' {
            firewall::service { 'bastion-bots-udp':
                proto  => 'udp',
                port   => 5071,
                srange => "(${bots_proxy_clients})",
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
