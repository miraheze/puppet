# role: mediawiki
class role::mediawiki {
    include ::mediawiki

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

    ::lizardfs::client {'/mnt/mediawiki-static':
        create_mountpoint => true,
    }

    ::lizardfs::client {'/mnt/mediawiki-trash':
        create_mountpoint => true,
        options           => 'mfsmeta',
    }
}
