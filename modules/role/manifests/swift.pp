# role: swift
class role::swift {
    include ::swift

    ufw::allow { 'swift mw1':
        proto => 'tcp',
        port  => 443,
        from  => '185.52.1.75',
    }

    ufw::allow { 'swift mw2':
        proto => 'tcp',
        port  => 443,
        from  => '185.52.2.113',
    }

    ufw::allow { 'swift mw3':
        proto => 'tcp',
        port  => 443,
        from  => '81.4.121.113',
    }

    ufw::allow { 'swift test1':
        proto => 'tcp',
        port  => 443,
        from  => '185.52.2.243',
    }

    motd::role { 'role::swift':
        description => 'Openstack Swift Object storage Proxy',
    }
}
