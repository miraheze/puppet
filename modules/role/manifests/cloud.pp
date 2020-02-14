# class: role::db
class role::db {
    class { '::cloud':
        main_ip4_address   => hiera('role::db::main_ip4_address'),
        main_ip4_netmask   => hiera('role::db::main_ip4_netmask'),
        main_ip4_broadcast => hiera('role::db::main_ip4_broadcast'),
        main_ip4_gateway   => hiera('role::db::main_ip4_gateway'),
        main_ip6_address   => hiera('role::db::main_ip6_address'),
        main_ip6_gateway   => hiera('role::db::main_ip6_gateway'),
    }

    # cloud1 and cloud2 respectivly
    # TODO: Either automate this or move it so it's done in a file
    ['54.36.165.86', '2001:41d0:800:1056::1', '54.36.165.90', '2001:41d0:800:105a::1'].each |String $ip| {
        ufw::allow { "proxmox port 5900:5999 ${ip}":
            proto => 'tcp',
            port  => '5900:5999',
            from  => $ip,
        }

        ufw::allow { "proxmox port 5404:5405 ${ip}":
            proto => 'udp',
            port  => '5404:5405',
            from  => $ip,
        }

        ufw::allow { "proxmox port 5404:5405 ${ip}":
            proto => 'udp',
            port  => '5404:5405',
            from  => $ip,
        }

        ufw::allow { "proxmox port 3128 ${ip}":
            proto => 'tcp',
            port  => '3128',
            from  => $ip,
        }

        ufw::allow { "proxmox port 8006 ${ip}":
            proto => 'tcp',
            port  => '8006',
            from  => $ip,
        }

        ufw::allow { "proxmox port 111 ${ip}":
            proto => 'tcp',
            port  => '111',
            from  => $ip,
        }
    }


    motd::role { 'role::cloud':
        description => 'cloud virts to host own vps using proxmox',
    }
}
