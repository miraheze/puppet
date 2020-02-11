# role: varnish
class role::varnish {
    include ::varnish

    ufw::allow { 'http port tcp':
        proto => 'tcp',
        port  => 80,
    }

    ufw::allow { 'https port tcp':
        proto => 'tcp',
        port  => 443,
    }

    ufw::allow { 'Direct Varnish access lizardfs6':
        proto => 'tcp',
        port  => 81,
        from  => '54.36.165.161',
    }

    ufw::allow { 'Direct Varnish access mw1':
        proto => 'tcp',
        port  => 81,
        from  => '185.52.1.75',
    }

    ufw::allow { 'Direct Varnish access mw2':
        proto => 'tcp',
        port  => 81,
        from  => '185.52.2.113',
    }

    ufw::allow { 'Direct Varnish access mw3':
        proto => 'tcp',
        port  => 81,
        from  => '81.4.121.113',
    }

    # new servers
    ufw::allow { 'Direct Varnish access mw4 ipv4':
        proto => 'tcp',
        port  => 81,
        from  => '51.89.160.128',
    }

    ufw::allow { 'Direct Varnish access mw4 ipv6':
        proto => 'tcp',
        port  => 81,
        from  => '2001:41d0:800:1056::3',
    }

    ufw::allow { 'Direct Varnish access mw5 ipv4':
        proto => 'tcp',
        port  => 81,
        from  => '51.89.160.133',
    }

    ufw::allow { 'Direct Varnish access mw5 ipv6':
        proto => 'tcp',
        port  => 81,
        from  => '2001:41d0:800:1056::8',
    }

    ufw::allow { 'Direct Varnish access mw6 ipv4':
        proto => 'tcp',
        port  => 81,
        from  => '51.89.160.136',
    }

    ufw::allow { 'Direct Varnish access mw6 ipv6':
        proto => 'tcp',
        port  => 81,
        from  => '2001:41d0:800:105a::4',
    }

    ufw::allow { 'Direct Varnish access mw7 ipv4':
        proto => 'tcp',
        port  => 81,
        from  => '51.89.160.137',
    }

    ufw::allow { 'Direct Varnish access mw7 ipv6':
        proto => 'tcp',
        port  => 81,
        from  => '2001:41d0:800:105a::5',
    }

    motd::role { 'role::varnish':
        description => 'Varnish caching server',
    }
}
