class role::mediawiki {
    include ::mediawiki
    include hhvm
    include nfs::client

    ufw::allow { 'http port tcp':
        proto => 'tcp',
        port  => 80,
    }

    ufw::allow { 'https port tcp':
        proto => 'tcp',
        port  => 443,
    }

    motd::role { 'role::mediawiki':
        description => 'MediaWiki server',
    }

    mount { '/mnt/mediawiki-static':
        ensure => mounted,
        device => '81.4.124.61:/srv/mediawiki-static',
        fstype => 'nfs',
        atboot => true,
    }
}
