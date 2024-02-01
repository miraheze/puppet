class role::bastion (
    $enable_proxy_ipv4_ipv6 = lookup('role::bastion::enable_proxy_ipv4_ipv6', {'default_value' => undef})
) {
    include squid

    motd::role { 'role::bastion':
        description => 'core access bastion host'
    }

    ferm::service { 'bastion-ssh-public':
        proto => 'tcp',
        port  => '22',
    }

    $squid_access_hosts_str = join(
        query_facts('', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

    ferm::service { 'bastion-squid':
        proto  => 'tcp',
        port   => '8080',
        srange => "(${squid_access_hosts_str})",
    }

    if $enable_proxy_ipv4_ipv6 {
        $backends = lookup('varnish::backends')
        $firewall_rules_str = join(
            query_facts('Class[Role::Varnish]', ['networking'])
            .map |$key, $value| {
                if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                    "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
                } elsif ( $value['networking']['interfaces']['ens18'] ) {
                    "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
                } else {
                    "${value['networking']['ip']} ${value['networking']['ip6']}"
                }
            }
            .flatten()
            .unique()
            .sort(),
            ' '
        )
        $firewall_rules_ports = join(
            $backends.map |$key, $value| {
                $value['port']
            }
            .flatten()
            .unique()
            .sort(),
            ' '
        )
        ferm::service { 'direct varnish access':
            proto   => 'tcp',
            port    => "(${firewall_rules_ports})",
            srange  => "(${firewall_rules_str})",
            notrack => true,
        }

        file { '/etc/nginx/sites-enabled/default':
            ensure => absent,
            notify => Service['nginx'],
        }

        nginx::site { 'mediawiki':
            ensure  => present,
            content => template('role/bastion/mediawiki.conf.erb'),
        }
    }
}
