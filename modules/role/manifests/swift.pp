# role: swift
class role::swift {
    include ::swift

    # http
    ufw::allow { 'swift mw1 8080':
        proto => 'tcp',
        port  => 8080,
        from  => '185.52.1.75',
    }

    ufw::allow { 'swift mw2 8080':
        proto => 'tcp',
        port  => 8080,
        from  => '185.52.2.113',
    }

    ufw::allow { 'swift mw3 8080':
        proto => 'tcp',
        port  => 8080,
        from  => '81.4.121.113',
    }

    ufw::allow { 'swift test1 8080':
        proto => 'tcp',
        port  => 8080,
        from  => '185.52.2.243',
    }

    ufw::allow { 'swift swift1 8080':
        proto => 'tcp',
        port  => 8080,
        from  => '81.4.101.157',
    }

    # misc4 access swift1
    ufw::allow { 'swift misc4 -> swift1 6000':
        proto => 'tcp',
        port  => 6000,
        from  => '185.52.3.121',
    }

    ufw::allow { 'swift misc4 -> swift1 6001':
        proto => 'tcp',
        port  => 6001,
        from  => '185.52.3.121',
    }

    ufw::allow { 'swift misc4 -> swift1 6002':
        proto => 'tcp',
        port  => 6002,
        from  => '185.52.3.121',
    }

    ufw::allow { 'swift misc4 -> swift1 6003':
        proto => 'tcp',
        port  => 6003,
        from  => '185.52.3.121',
    }

    # misc4 access swift2
    ufw::allow { 'swift misc4 -> swift2 6000':
        proto => 'tcp',
        port  => 6000,
        from  => '81.4.124.61',
    }

    ufw::allow { 'swift misc4 -> swift2 6001':
        proto => 'tcp',
        port  => 6001,
        from  => '81.4.124.61',
    }

    ufw::allow { 'swift misc4 -> swift2 6002':
        proto => 'tcp',
        port  => 6002,
        from  => '81.4.124.61',
    }

    ufw::allow { 'swift misc4 -> swift2 6003':
        proto => 'tcp',
        port  => 6003,
        from  => '81.4.124.61',
    }

    # rsync data
    ufw::allow { 'rsync swift1 -> swift2 6003':
        proto => 'tcp',
        port  => 873,
        from  => '81.4.101.157',
    }

    ufw::allow { 'rsync swift2 -> swift1 873':
        proto => 'tcp',
        port  => 873,
        from  => '81.4.124.61',
    }

    motd::role { 'role::swift':
        description => 'Openstack Swift Object storage Proxy',
    }
}
