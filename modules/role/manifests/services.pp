# role: services
class role::services {
    include ::profile::citoid

    include ::profile::electron

    include ::profile::parsoid

    include ::profile::restbase


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

    ufw::allow { 'electron monitoring':
        proto => 'tcp',
        port  => 3000,
        from  => '185.52.1.76',
    }

    ufw::allow { 'electron monitoring':
        proto => 'tcp',
        port  => 3000,
        from  => '185.52.1.76',
    }

    ufw::allow { 'parsoid mw1':
        proto => 'tcp',
        port  => 443,
        from  => '185.52.1.75',
    }

    ufw::allow { 'parsoid mw2':
        proto => 'tcp',
        port  => 443,
        from  => '185.52.2.113',
    }
    ufw::allow { 'parsoid mw3':
        proto => 'tcp',
        port  => 443,
        from  => '81.4.121.113',
    }

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

    ufw::allow { 'restbase monitoring':
        proto => 'tcp',
        port  => 7231,
        from  => '185.52.1.76',
    }

    motd::role { 'role::services':
        description => 'Hosting MediaWiki services (citoid, electron, parsoid, restbase etc)',
    }
}
