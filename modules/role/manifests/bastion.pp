class role::bastion (
    Optional[String] $higher_timeout = lookup('role::bastion::higher_timeout', {'default_value' => undef}),
) {
    include base

    if $higher_timeout {
        include squid
        class { 'squid':
            config_source => 'puppet:///modules/role/bastion/squid.conf'
        }
    } else {
        include squid
    }

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
