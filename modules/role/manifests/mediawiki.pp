# role: mediawiki
class role::mediawiki {
    include ::mediawiki
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
