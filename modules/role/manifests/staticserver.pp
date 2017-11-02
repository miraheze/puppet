# NFS static content server
class role::staticserver {
    nfs::server { 'static':
        mountroot   => '/srv/mediawiki-static',
        exportsfile => 'puppet:///modules/role/staticserver/exports',
    }

    ufw::allow { 'nfs annoyance (mw1)':
        from => '185.52.1.75',
    }

    ufw::allow { 'nfs annoyance (mw2)':
        from => '185.52.2.113',
    }
	
    ufw::allow { 'nfs annoyance (mw3)':
        from => '81.4.121.113',
    }

    ufw::allow { 'nfs annoyance (test1)':
        from => '185.52.2.243',
    }

    motd::role { 'role::staticserver':
        description => 'static hosting server',
    }
}
