# class: role::db
class role::db {
    include ::cloud

    # cloud1 and cloud2 respectivly
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
