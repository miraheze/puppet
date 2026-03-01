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
        $subquery = @("PQL")
        (resources { type = 'Class' and title = 'Role::Mediawiki' } or
        resources { type = 'Class' and title = 'Role::Mediawiki_task' } or
        resources { type = 'Class' and title = 'Role::Mediawiki_beta' } or
        resources { type = 'Class' and title = 'Role::Icinga2' })
        | PQL
        $cloudflare_firewall_rule = $cloudflare_ipv4 + $cloudflare_ipv6 + vmlib::generate_firewall_ip($subquery)
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

    $subquery = @("PQL")
    (resources { type = 'Class' and title = 'Role::Mediawiki' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_task' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_beta' })
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)
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
