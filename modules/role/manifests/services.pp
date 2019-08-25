# role: services
class role::services {
    if hiera('enable_citoid', true) {
        include ::profile::citoid

        ufw::allow { 'citoid monitoring':
            proto => 'tcp',
            port  => 6927,
            from  => '185.52.1.76',
        }

        ufw::allow { 'zotero monitoring':
            proto => 'tcp',
            port  => 1969,
            from  => '185.52.1.76',
        }
    }

    if hiera('enable_electron', true) {
        include ::profile::electron

        ufw::allow { 'electron monitoring':
            proto => 'tcp',
            port  => 3000,
            from  => '185.52.1.76',
        }
    }

    if hiera('enable_parsoid', true) {
        include ::profile::parsoid

        ufw::allow { 'parsoid monitoring':
            proto => 'tcp',
            port  => 8142,
            from  => '185.52.1.76',
        }

        ufw::allow { 'parsoid test1':
            proto => 'tcp',
            port  => 443,
            from  => '185.52.2.243',
        }
    }

    if hiera('enable_proton', true) {
        include ::profile::proton

        ufw::allow { 'proton monitoring':
            proto => 'tcp',
            port  => 3030,
            from  => '185.52.1.76',
        }
    }

    if hiera('enable_restbase', true) {
        include ::profile::restbase

        ufw::allow { 'restbase monitoring':
            proto => 'tcp',
            port  => 7231,
            from  => '185.52.1.76',
        }
    }

    ufw::allow { 'mw1 443':
        proto => 'tcp',
        port  => 443,
        from  => '185.52.1.75',
    }

    ufw::allow { 'mw2 443':
        proto => 'tcp',
        port  => 443,
        from  => '185.52.2.113',
    }

    ufw::allow { 'mw3 443':
        proto => 'tcp',
        port  => 443,
        from  => '81.4.121.113',
    }

    ufw::allow { 'test1 443':
        proto => 'tcp',
        port  => 443,
        from  => '185.52.2.243',
    }

    motd::role { 'role::services':
        description => 'Hosting MediaWiki services (citoid, electron, parsoid, restbase etc)',
    }
}
