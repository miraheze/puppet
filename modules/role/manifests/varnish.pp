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

    motd::role { 'role::varnish':
        description => 'Varnish caching server',
    }
}
