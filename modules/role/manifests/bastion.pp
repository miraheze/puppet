class role::bastion (
    Boolean $webproxy_gateway = false,
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
        $webproxy_clients = vmlib::generate_firewall_ip($webproxy_clients_query)

        class { 'webproxy::gateway':
            srange => "(${webproxy_clients})",
            allow  => ['127.0.0.1'] + split($webproxy_clients, ' ').filter |$ip| { $ip != '' },
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
