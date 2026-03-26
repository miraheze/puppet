# role: reports
class role::reports {
    include reports

    $cloudflare_ipv4 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv4'), /[\r\n]/)
    $cloudflare_ipv6 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv6'), /[\r\n]/)

    $subquery = @("PQL")
    (resources { type = 'Class' and title = 'Role::Varnish' } or
    resources { type = 'Class' and title = 'Role::Cache::Cache' } or
    resources { type = 'Class' and title = 'Role::Icinga2' })
    | PQL
    $cf_ip = join($cloudflare_ipv4 + $cloudflare_ipv6, ' ')
    $ip = vmlib::generate_firewall_ip($subquery)
    $firewall_srange = "${cf_ip} ${ip}"

    ferm::service { 'http':
        proto   => 'tcp',
        port    => '80',
        srange  => "(${firewall_srange})",
        notrack => true,
    }

    ferm::service { 'https':
        proto   => 'tcp',
        port    => '443',
        srange  => "(${firewall_srange})",
        notrack => true,
    }

    system::role { 'reports':
        description => 'TSPortal-hosting server',
    }
}
