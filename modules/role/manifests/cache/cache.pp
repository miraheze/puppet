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
        $subquery = @("PQL")
        (resources { type = 'Class' and title = 'Role::Mediawiki' } or
        resources { type = 'Class' and title = 'Role::Mediawiki_task' } or
        resources { type = 'Class' and title = 'Role::Mediawiki_beta' } or
        resources { type = 'Class' and title = 'Role::Icinga2' })
        | PQL
        $cf_ip = join($cloudflare_ipv4 + $cloudflare_ipv6, ' ')
        $ip = vmlib::generate_firewall_ip($subquery)
        $cloudflare_firewall_rule = "${cf_ip} ${ip}"

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

    $subquery_2 = @("PQL")
    (resources { type = 'Class' and title = 'Role::Mediawiki' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_task' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_beta' } or
    resources { type = 'Class' and title = 'Role::Cache::Varnish' })
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery_2)
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
