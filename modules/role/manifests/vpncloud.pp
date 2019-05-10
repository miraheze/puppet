# role: vpncloud
class role::vpncloud {
    include ::vpncloud

    ufw::allow { 'vpncloud port tcp cp2':
        proto   => 'tcp',
        port    => 3210,
        from    => '107.191.126.23',
    }

    ufw::allow { 'vpncloud port tcp cp3':
        proto   => 'tcp',
        port    => 3210,
        from    => '128.199.139.216',
    }
 
     ufw::allow { 'vpncloud port tcp cp4':
        proto   => 'tcp',
        port    => 3210,
        from    => '81.4.109.133',
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

    ufw::allow { 'vpncloud port tcp mw1':
        proto   => 'tcp',
        port    => 3210,
        from    => '185.52.1.75',
    }

    ufw::allow { 'vpncloud port tcp mw2':
        proto   => 'tcp',
        port    => 3210,
        from    => '185.52.2.113',
    }

    ufw::allow { 'vpncloud port tcp mw3':
        proto   => 'tcp',
        port    => 3210,
        from    => '81.4.121.113',
    }

    motd::role { 'role::vpncloud':
        description => 'server with VPNCloud (experimental)',
    }
}
