# role: mediawiki
class role::mediawiki {
    include ::mediawiki

    if hiera('role::mediawiki::use_strict_firewall', false) {
        # Cache proxies will never use port 80.

        ufw::allow { 'https port cp2':
            proto => 'tcp',
            port  => 443,
            from  => '107.191.126.23',
        }

        ufw::alow { ' https port cp3':
            proto => 'tcp',
            port  => 443,
            from  => '128.199.139.216',
        }

        ufw::allow { 'https port cp4':
            proto => 'tcp',
            port  => 443,
            from  => '81.4.109.133',
        }

        ufw::allow { 'https port icinga':
            proto => 'tcp',
            port  => 443,
            from  => '185.52.1.76'
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
        options           => 'big_writes,nosuid,nodev,noatime,mfsioretries=3,mfswriteworkers=15,mfsattrcacheto=60.0,mfsentrycacheto=60.0,mfsdirentrycacheto=60.0,mfsdirentrycachesize=3000,readaheadmaxwindowsize=500,cacheexpirationtime=300',
    }
}
