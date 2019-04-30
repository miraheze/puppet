# role: vpncloud
class role::vpncloud {
    include ::vpncloud
 
    ufw::allow { 'vpncloud port tcp mw2':
        proto   => 'tcp',
        port    => 3120,
        from    => '185.52.2.113',
    }

    ufw::allow { 'vpncloud port tcp cp3':
        proto   => 'tcp',
        port    => 3120,
        from    => '128.199.139.216',
    }
 
    ufw::allow { 'vpncloud port tcp test1':
        proto   => 'tcp',
        port    => 3120,
        from    => '185.52.2.243',
    }
    
    motd::role { 'role::vpncloud':
        description => 'server with VPNCloud (experimental)',
    }
}
