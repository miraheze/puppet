# firewall for all servers
class base::ufw {
    include ::ufw

    ufw::allow { 'ssh':
        proto => 'tcp',
        port  => 22,
    }

    $firewallRules = query_facts('Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])
    $firewallRules.each |$key, $value| {
        ufw::allow { "nrpe ${value['ipaddress']} IPv4":
            proto => 'tcp',
            port  => 5666,
            from  => $value['ipaddress'],
        }

        ufw::allow { "nrpe ${value['ipaddress6']} IPv6":
            proto => 'tcp',
            port  => 5666,
            from  => $value['ipaddress6'],
        }
    }

    file { '/root/ufw-fix':
        ensure => present,
        source => 'puppet:///modules/base/ufw/ufw-fix',
        mode   => '0755',
    }
}
