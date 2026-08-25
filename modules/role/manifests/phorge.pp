# role: phorge
class role::phorge {
    include phorge

    $cloudflare_ipv4 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv4'), /[\r\n]/)
    $cloudflare_ipv6 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv6'), /[\r\n]/)
    $cf_ip = join($cloudflare_ipv4 + $cloudflare_ipv6, ' ')

    firewall::service { 'http':
        proto    => 'tcp',
        port     => 80,
        srange   => "(${cf_ip})",
        src_sets => ['VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
        notrack  => true,
    }

    firewall::service { 'https':
        proto    => 'tcp',
        port     => 443,
        srange   => "(${cf_ip})",
        src_sets => ['VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
        notrack  => true,
    }

    system::role { 'phorge':
        description => 'Phorge instance',
    }
}
