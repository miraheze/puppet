# role: varnish
class role::varnish (
    Boolean $restrict_firewall = lookup('role::varnish::restrict_firewall', {'default_value' => false}),
) {
    include ::varnish
    include fail2ban
    include prometheus::exporter::varnishreqs
    include role::cache::perfs

    # Temporarily disabling this due to
    # service keep being restarted on
    # puppet runs.
    # ferm::conf { 'varnish-connlimits':
    #    prio    => '01',
    #    source  => 'puppet:///modules/role/firewall/varnish-connlimits.conf'
    # }

    if $restrict_firewall {
        $cloudflare_ipv4 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv4'), /[\r\n]/)
        $cloudflare_ipv6 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv6'), /[\r\n]/)
        $cloudflare_firewall_rule = join(
            $cloudflare_ipv4 + $cloudflare_ipv6 + query_facts('Class[Role::Mediawiki] or Class[Role::Mediawiki_task] or Class[Role::Mediawiki_beta] or Class[Role::Icinga2]', ['networking'])
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
        ferm::service { 'http':
            proto   => 'tcp',
            port    => '80',
            srange  => "(${cloudflare_firewall_rule})",
            notrack => true,
        }

        ferm::service { 'https':
            proto   => 'tcp',
            port    => '443',
            srange  => "(${cloudflare_firewall_rule})",
            notrack => true,
        }
    } else {
        ferm::service { 'http':
            proto   => 'tcp',
            port    => '80',
            notrack => true,
        }

        ferm::service { 'https':
            proto   => 'tcp',
            port    => '443',
            notrack => true,
        }
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Mediawiki] or Class[Role::Mediawiki_task] or Class[Role::Mediawiki_beta]', ['networking'])
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
    ferm::service { 'direct varnish access':
        proto   => 'tcp',
        port    => '81',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    system::role { 'varnish':
        description => 'Varnish caching server',
    }
}
