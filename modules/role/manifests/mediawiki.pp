# role: mediawiki
class role::mediawiki {
    include ::mediawiki

    if !defined(Exec['ufw-allow-tcp-from-any-to-any-port-80']) {
        ufw::allow { 'http port tcp':
            proto => 'tcp',
            port  => 80,
        }
    }

    if !defined(Exec['ufw-allow-tcp-from-any-to-any-port-443']) {
        ufw::allow { 'https port tcp':
            proto => 'tcp',
            port  => 443,
        }
    }

    motd::role { 'role::mediawiki':
        description => 'MediaWiki server',
    }

    ::lizardfs::client {'/mnt/mediawiki-static':
        create_mountpoint => true,
        options           => 'big_writes,nosuid,nodev,noatime',
    }

    ::lizardfs::client {'/mnt/mediawiki-trash':
        create_mountpoint => true,
        options           => 'mfsmeta',
    }
}
