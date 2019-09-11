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

    if hiera('use_gluster_mount', false) {
        $gluster_volume_backup = hiera('gluster_volume_backup', 'glusterfs2.miraheze.org:/prodvol')
        gluster::mount { '/mnt/mediawiki-static':
          ensure    => present,
          volume    => hiera('gluster_volume', 'glusterfs1.miraheze.org:/prodvol'),
          transport => 'tcp',
          atboot    => false,
          dump      => 0,
          pass      => 0,
          options   => "backup-volfile-servers=${gluster_volume_backup}",
        }
    } else {
        ::lizardfs::client { '/mnt/mediawiki-static':
            create_mountpoint => true,
            options           => 'big_writes,nosuid,nodev,noatime',
        }

        ::lizardfs::client { '/mnt/mediawiki-trash':
            create_mountpoint => true,
            options           => 'mfsmeta',
        }
    }
}
