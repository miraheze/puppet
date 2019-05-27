# role: vpncloud
class role::vpncloud {
    include ::vpncloud

    $vpncloud_hosts = query_nodes('Class[Role::Vpncloud]', 'networking.interfaces.venet0:0.network')
    $vpncloud_hosts.each |$ip| {
        ufw::allow { "vpncloud port tcp ${ip}":
            proto   => 'tcp',
            port    => 3210,
            from    => $ip,
        }
    }

    motd::role { 'role::vpncloud':
        description => 'server with VPNCloud (experimental)',
    }
}
