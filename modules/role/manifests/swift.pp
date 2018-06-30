# role: swift
class role::swift {
    include ::swift

    # http
    ufw::allow { 'swift mw1 80':
        proto => 'tcp',
        port  => 80,
        from  => '185.52.1.75',
    }

    ufw::allow { 'swift mw2 80':
        proto => 'tcp',
        port  => 80,
        from  => '185.52.2.113',
    }

    ufw::allow { 'swift mw3 80':
        proto => 'tcp',
        port  => 80,
        from  => '81.4.121.113',
    }

    ufw::allow { 'swift test1 80':
        proto => 'tcp',
        port  => 80,
        from  => '185.52.2.243',
    }
    
    # https
    ufw::allow { 'swift mw1 443':
        proto => 'tcp',
        port  => 443,
        from  => '185.52.1.75',
    }

    ufw::allow { 'swift mw2 443':
        proto => 'tcp',
        port  => 443,
        from  => '185.52.2.113',
    }

    ufw::allow { 'swift mw3 443':
        proto => 'tcp',
        port  => 443,
        from  => '81.4.121.113',
    }

    ufw::allow { 'swift test1 443':
        proto => 'tcp',
        port  => 443,
        from  => '185.52.2.243',
    }

    motd::role { 'role::swift':
        description => 'Openstack Swift Object storage Proxy',
    }
}
