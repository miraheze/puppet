# role: vpncloud
class role::vpncloud {
    include ::vpncloud
 
    ufw::allow { 'vpncloud port tcp mw2':
        proto   => 'tcp',
        port    => 3210,
        from    => '185.52.2.113',
    }

    ufw::allow { 'vpncloud port tcp cp3':
        proto   => 'tcp',
        port    => 3210,
        from    => '128.199.139.216',
    }
 
    ufw::allow { 'vpncloud port tcp test1':
        proto   => 'tcp',
        port    => 3210,
        from    => '185.52.2.243',
    }
    
    ufw::allow { 'vpncloud port tcp db4':
        proto   => 'tcp',
        port    => 3210,
        from    => '81.4.109.166',
    }

    ufw::allow { 'vpncloud port tcp ns1':
        proto   => 'tcp',
        port    => 3210,
        from    => '192.184.82.120',
    }

    ufw::allow { 'vpncloud port tcp puppet1':
        proto   => 'tcp',
        port    => 3210,
        from    => '81.4.127.229',
    }

    motd::role { 'role::vpncloud':
        description => 'server with VPNCloud (experimental)',
    }
}
