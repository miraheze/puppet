# class: role::cloud
class role::cloud {
    class { '::cloud':
        main_interface     => hiera('role::cloud::main_interface'),
        main_ip4_address   => hiera('role::cloud::main_ip4_address'),
        main_ip4_netmask   => hiera('role::cloud::main_ip4_netmask'),
        main_ip4_broadcast => hiera('role::cloud::main_ip4_broadcast'),
        main_ip4_gateway   => hiera('role::cloud::main_ip4_gateway'),
        main_ip6_address   => hiera('role::cloud::main_ip6_address'),
        main_ip6_gateway   => hiera('role::cloud::main_ip6_gateway'),
    }

    # cloud1 and cloud2 respectivly
    # TODO: Either automate this or move it so it's done in a file
    $firewall = query_facts('Class[Role::Cloud]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "proxmox port 5900:5999 ${value['ipaddress']}":
            proto => 'tcp',
            port  => '5900:5999',
            from  => $value['ipaddress'],
        }

        ufw::allow { "proxmox port 5900:5999 ${value['ipaddress6']}":
            proto => 'tcp',
            port  => '5900:5999',
            from  => $value['ipaddress6'],
        }

        ufw::allow { "proxmox port 5404:5405 ${value['ipaddress']}":
            proto => 'udp',
            port  => '5404:5405',
            from  => $value['ipaddress'],
        }

        ufw::allow { "proxmox port 5404:5405 ${value['ipaddress6']}":
            proto => 'udp',
            port  => '5404:5405',
            from  => $value['ipaddress6'],
        }

        ufw::allow { "proxmox port 3128 ${value['ipaddress']}":
            proto => 'tcp',
            port  => '3128',
            from  => $value['ipaddress'],
        }

        ufw::allow { "proxmox port 3128 ${value['ipaddress6']}":
            proto => 'tcp',
            port  => '3128',
            from  => $value['ipaddress6'],
        }

        ufw::allow { "proxmox port 8006 ${value['ipaddress']}":
            proto => 'tcp',
            port  => '8006',
            from  => $value['ipaddress'],
        }

        ufw::allow { "proxmox port 8006 ${value['ipaddress6']}":
            proto => 'tcp',
            port  => '8006',
            from  => $value['ipaddress6'],
        }

        ufw::allow { "proxmox port 111 ${value['ipaddress']}":
            proto => 'tcp',
            port  => '111',
            from  => $value['ipaddress'],
        }

        ufw::allow { "proxmox port 111 ${value['ipaddress6']}":
            proto => 'tcp',
            port  => '111',
            from  => $value['ipaddress6'],
        }
    }


    motd::role { 'role::cloud':
        description => 'cloud virts to host own vps using proxmox',
    }
}
