# firewall for all servers
class base::ufw {
    include ::ufw

    ufw::allow { 'ssh':
        proto => 'tcp',
        port  => 22,
    }

    $firewallIpv4 = query_nodes("domain='$domain' and Class[Role::Icinga2]", 'ipaddress')
    $firewallIpv4.each |$key| {
        ufw::allow { "nrpe ${key}":
            proto => 'tcp',
            port  => 5666,
            from  => $key,
        }
    }

    $firewallIpv6 = query_nodes("domain='$domain' and Class[Role::Icinga2]", 'ipaddress6')
    $firewallIpv6.each |$key| {
        ufw::allow { "nrpe ${key}":
            proto => 'tcp',
            port  => 5666,
            from  => $key,
        }
    }

    file { '/root/ufw-fix':
        ensure => present,
        source => 'puppet:///modules/base/ufw/ufw-fix',
        mode   => '0755',
    }
}
