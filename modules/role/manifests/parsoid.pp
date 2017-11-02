# role: parsoid
class role::parsoid {
    include ::parsoid

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

    motd::role { 'role::parsoid':
        description => 'parsoid server',
    }
}
