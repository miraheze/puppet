# role: services
class role::services {
    if lookup('enable_citoid', {'default_value' => true}) {
        include ::profile::citoid

        ufw::allow { 'citoid monitoring ipv4':
            proto => 'tcp',
            port  => 6927,
            from  => '51.89.160.138',
        }

        ufw::allow { 'citoid monitoring ipv6':
            proto => 'tcp',
            port  => 6927,
            from  => '2001:41d0:800:105a::6',
        }

        ufw::allow { 'zotero monitoring ipv4':
            proto => 'tcp',
            port  => 1969,
            from  => '51.89.160.138',
        }

        ufw::allow { 'zotero monitoring ipv6':
            proto => 'tcp',
            port  => 1969,
            from  => '2001:41d0:800:105a::6',
        }
    }

    if lookup('enable_parsoid', {'default_value' => true}) {
        include ::profile::parsoid

        ufw::allow { 'parsoid monitoring ipv4':
            proto => 'tcp',
            port  => 8142,
            from  => '51.89.160.138',
        }

        ufw::allow { 'parsoid monitoring ipv6':
            proto => 'tcp',
            port  => 8142,
            from  => '2001:41d0:800:105a::6',
        }
    }

    if lookup('enable_proton', {'default_value' => true}) {
        include ::profile::proton

        ufw::allow { 'proton monitoring ipv4':
            proto => 'tcp',
            port  => 3030,
            from  => '51.89.160.138',
        }

        ufw::allow { 'proton monitoring ipv6':
            proto => 'tcp',
            port  => 3030,
            from  => '2001:41d0:800:105a::6',
        }
    }

    if lookup('enable_restbase', {'default_value' => true}) {
        include ::profile::restbase

        ufw::allow { 'restbase monitoring ipv4':
            proto => 'tcp',
            port  => 7231,
            from  => '51.89.160.138',
        }

        ufw::allow { 'restbase monitoring ipv6':
            proto => 'tcp',
            port  => 7231,
            from  => '2001:41d0:800:105a::6',
        }
    }

    # new servers
    ufw::allow { 'mw4 ipv4 443':
        proto => 'tcp',
        port  => 443,
        from  => '51.89.160.128',
    }

    ufw::allow { 'mw4 ipv6 443':
        proto => 'tcp',
        port  => 443,
        from  => '2001:41d0:800:1056::3',
    }

    ufw::allow { 'mw5 ipv4 443':
        proto => 'tcp',
        port  => 443,
        from  => '51.89.160.133',
    }

    ufw::allow { 'mw5 ipv6 443':
        proto => 'tcp',
        port  => 443,
        from  => '2001:41d0:800:1056::8',
    }

    ufw::allow { 'mw6 ipv4 443':
        proto => 'tcp',
        port  => 443,
        from  => '51.89.160.136',
    }

    ufw::allow { 'mw6 ipv6 443':
        proto => 'tcp',
        port  => 443,
        from  => '2001:41d0:800:105a::4',
    }

    ufw::allow { 'mw7 ipv4 443':
        proto => 'tcp',
        port  => 443,
        from  => '51.89.160.137',
    }

    ufw::allow { 'mw7 ipv6 443':
        proto => 'tcp',
        port  => 443,
        from  => '2001:41d0:800:105a::5',
    }

    ufw::allow { 'test2 ipv4 443':
        proto => 'tcp',
        port  => 443,
        from  => '51.77.107.211',
    }

    ufw::allow { 'test2 ipv6 443':
        proto => 'tcp',
        port  => 443,
        from  => '2001:41d0:800:105a::3',
    }

    motd::role { 'role::services':
        description => 'Hosting MediaWiki services (citoid, electron, parsoid, restbase etc)',
    }
}
