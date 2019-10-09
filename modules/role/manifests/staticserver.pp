# NFS static content server
class role::staticserver {
    nfs::server { 'static':
        mountroot   => '/mnt/mediawiki-static',
        exportsfile => 'puppet:///modules/role/staticserver/exports',
    }

    ufw::allow { 'nfs (mw1)':
        port => 'all',
        # lizardfs master ip, change when the master changes.
        ip   => '185.52.1.71',
        from => '185.52.1.75',
    }

    ufw::allow { 'nfs (mw2)':
        port => 'all',
        # lizardfs master ip, change when the master changes.
        ip   => '185.52.1.71',
        from => '185.52.2.113',
    }
	
    ufw::allow { 'nfs (mw3)':
        port => 'all',
        # lizardfs master ip, change when the master changes.
        ip   => '185.52.1.71',
        from => '81.4.121.113',
    }

    ufw::allow { 'nfs (test1)':
        port => 'all',
        # lizardfs master ip, change when the master changes.
        ip   => '185.52.1.71',
        from => '185.52.2.243',
    }

    motd::role { 'role::staticserver':
        description => 'static hosting server',
    }
}
