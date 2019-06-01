# role: vpncloud
class role::vpncloud {
    include ::vpncloud

    ufw::allow { 'vpncloud port tcp cp2 ipv4':
        proto   => 'tcp',
        port    => 3210,
        from    => '107.191.126.23',
    }

    ufw::allow { 'vpncloud port tcp cp2 ipv6':
        proto   => 'tcp',
        port    => 3210,
        from    => '2604:180:0:33b::2',
    }

    ufw::allow { 'vpncloud port tcp cp3 ipv4':
        proto   => 'tcp',
        port    => 3210,
        from    => '128.199.139.216',
    }

    ufw::allow { 'vpncloud port tcp cp3 ipv6':
        proto   => 'tcp',
        port    => 3210,
        from    => '2400:6180:0:d0::403:f001',
    }
 
     ufw::allow { 'vpncloud port tcp cp4 ipv4':
        proto   => 'tcp',
        port    => 3210,
        from    => '81.4.109.133',
    }

     ufw::allow { 'vpncloud port tcp cp4 ipv6':
        proto   => 'tcp',
        port    => 3210,
        from    => '2a00:d880:5:8ea::ebc7',
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

    ufw::allow { 'vpncloud port tcp lizardfs1':
        proto   => 'tcp',
        port    => 3210,
        from    => '81.4.101.157',
    }

    ufw::allow { 'vpncloud port tcp lizardfs2':
        proto   => 'tcp',
        port    => 3210,
        from    => '81.4.124.61',
    }

    ufw::allow { 'vpncloud port tcp lizardfs3':
        proto   => 'tcp',
        port    => 3210,
        from    => '168.235.109.27',
    }

    ufw::allow { 'vpncloud port tcp misc1 ipv4':
        proto   => 'tcp',
        port    => 3210,
        from    => '185.52.1.76',
    }

    ufw::allow { 'vpncloud port tcp misc1 ipv6':
        proto   => 'tcp',
        port    => 3210,
        from    => '2a00:d880:6:787::2',
    }

    ufw::allow { 'vpncloud port tcp misc2':
        proto   => 'tcp',
        port    => 3210,
        from    => '81.4.127.174',
    }

    ufw::allow { 'vpncloud port tcp misc3':
        proto   => 'tcp',
        port    => 3210,
        from    => '185.52.1.144',
    }

    ufw::allow { 'vpncloud port tcp misc4 ipv4':
        proto   => 'tcp',
        port    => 3210,
        from    => '185.52.3.121',
    }

    ufw::allow { 'vpncloud port tcp misc4 ipv6':
        proto   => 'tcp',
        port    => 3210,
        from    => '2a00:d880:5:7c6::2',
    }

    ufw::allow { 'vpncloud port tcp mw1 ipv4':
        proto   => 'tcp',
        port    => 3210,
        from    => '185.52.1.75',
    }

    ufw::allow { 'vpncloud port tcp mw1 ipv6':
        proto   => 'tcp',
        port    => 3210,
        from    => '2a00:d880:6:786::2',
    }

    ufw::allow { 'vpncloud port tcp mw2 ipv4':
        proto   => 'tcp',
        port    => 3210,
        from    => '185.52.2.113',
    }

    ufw::allow { 'vpncloud port tcp mw2 ipv6':
        proto   => 'tcp',
        port    => 3210,
        from    => '2a00:d880:5:799::2',
    }

    ufw::allow { 'vpncloud port tcp mw3 ipv4':
        proto   => 'tcp',
        port    => 3210,
        from    => '81.4.121.113',
    }

    ufw::allow { 'vpncloud port tcp mw3 ipv6':
        proto   => 'tcp',
        port    => 3210,
        from    => '2a00:d880:5:b45::2',
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
