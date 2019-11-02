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

    # Add mfschunkserverreadto=20000 when client is >= 3.12
    ::lizardfs::client { '/mnt/mediawiki-static':
        create_mountpoint => true,
        options           => 'big_writes,nosuid,nodev,noatime,mfsattrcacheto=30.0,mfsentrycacheto=30.0,mfsdirentrycacheto=30.0,mfsdirentrycachesize=3000,mfswriteworkers=50,async',
    }

    if hiera('use_gluster_new', false) {
        include gluster::apt

        # $gluster_volume_backup = hiera('gluster_volume_backup', 'glusterfs2.miraheze.org:/prodvol')
        # backup-volfile-servers=
        gluster::mount { '/mnt/mediawiki-static-new':
          ensure    => present,
          volume    => hiera('gluster_volume', 'lizardfs6.miraheze.org:/prodvol'),
          transport => 'tcp',
          atboot    => false,
          dump      => 0,
          pass      => 0,
        }
    }
}
