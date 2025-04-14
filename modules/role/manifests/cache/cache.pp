# role: varnish
class role::cache::cache (
    Boolean $restrict_firewall = lookup('role::cache::cache::restrict_firewall', {'default_value' => false}),
) {
    include base
    include role::cache::varnish
    include role::cache::haproxy
    include role::cache::perfs

    if $restrict_firewall {
        $cloudflare_ipv4 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv4'), /[\r\n]/)
        $cloudflare_ipv6 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv6'), /[\r\n]/)
        $cloudflare_firewall_rule = join(
            $cloudflare_ipv4 + $cloudflare_ipv6 + query_facts('Class[Role::Mediawiki] or Class[Role::Mediawiki_task] or Class[Role::Mediawiki_beta] or Class[Role::Icinga2]', ['networking'])
            .map |$key, $value| {
                if ( $value['networking']['interfaces']['he-ipv6'] ) {
                    "${value['networking']['ip']} ${value['networking']['interfaces']['he-ipv6']['ip6']}"
                } elsif ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
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
        query_facts('Class[Role::Mediawiki] or Class[Role::Mediawiki_task] or Class[Role::Mediawiki_beta] or Class[Role::Cache::Varnish]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['he-ipv6'] ) {
                "${value['networking']['ip']} ${value['networking']['interfaces']['he-ipv6']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
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

    system::role { 'cache':
        description => 'Runs HAProxy for frontend and varnish for caching server',
    }
}
