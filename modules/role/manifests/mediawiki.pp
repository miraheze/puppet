class role::mediawiki {
    include ::mediawiki
    include nfs::client

    $cp_ips = ['81.4.124.61', '107.191.126.23']
    
    $cp_ips.each |String $cp_ip| {
        ufw::allow { "https port ${cp_ip} tcp":
            proto => 'tcp',
            port  => 443,
            from  => $cp_ip,
        }
    }

    motd::role { 'role::mediawiki':
        description => 'MediaWiki server',
    }

    file { '/mnt/mediawiki-static':
        ensure => directory,
    }

    mount { '/mnt/mediawiki-static':
        ensure  => mounted,
        device  => '81.4.124.61:/srv/mediawiki-static',
        fstype  => 'nfs',
        options => 'rw',
        atboot  => true,
        require => File['/mnt/mediawiki-static'],
    }
}
