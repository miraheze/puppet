# role: mediawiki
class role::mediawiki {
    include ::mediawiki

    if (hiera('role::mediawiki::use_strict_firewall', false)) {
        # Cache proxies will never use port 80.

        ufw::allow { 'https port cp2':
            proto => 'tcp',
            port  => 443,
            from  => '107.191.126.63',
        }

        ufw::allow { 'https port cp4':
            proto => 'tcp',
            port  => 443,
            from  => '81.4.109.133',
        }

        ufw::allow { 'https port cp5':
            proto => 'tcp',
            port  => 443,
            from  => '172.104.111.8',
        }
    } else {
        ufw::allow { 'http port tcp':
            proto => 'tcp',
            port  => 80,
        }

        ufw::allow { 'https port tcp':
            proto => 'tcp',
            port  => 443,
        }
    }

    motd::role { 'role::mediawiki':
        description => 'MediaWiki server',
    }

    ::lizardfs::client { '/mnt/mediawiki-static':
        create_mountpoint => true,
        options           => 'big_writes,nosuid,nodev,noatime',
    }

    ::lizardfs::client { '/mnt/mediawiki-trash':
        create_mountpoint => true,
        options           => 'mfsmeta',
    }
}
