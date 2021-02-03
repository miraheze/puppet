# role: varnish
class role::varnish {
    include ::varnish

    ufw::allow { 'http port tcp':
        proto => 'tcp',
        port  => 80,
    }

    ufw::allow { 'https port tcp':
        proto => 'tcp',
        port  => 443,
    }

    $firewall = query_facts('Class[Role::Mediawiki]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "Direct Varnish access ipv4 ${value['ipaddress']}":
            proto => 'tcp',
            port  => 81,
            from  => $value['ipaddress'],
        }

        ufw::allow { "Direct Varnish access ipv6 ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 81,
            from  => $value['ipaddress6'],
        }
    }

    motd::role { 'role::varnish':
        description => 'Varnish caching server',
    }
}
