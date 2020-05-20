# role: mediawiki
class role::mediawiki {
    include ::mediawiki

    if lookup('role::mediawiki::use_strict_firewall', {'default_value' => false}) {
        # Cache proxies will never use port 80.

        ufw::allow { 'https port cp3':
            proto => 'tcp',
            port  => 443,
            from  => '128.199.139.216',
        }

        ufw::allow { 'https port cp8':
            proto => 'tcp',
            port  => 443,
            from  => '51.161.32.127',
        }

        ufw::allow { 'https port icinga ipv4':
            proto => 'tcp',
            port  => 443,
            from  => '51.89.160.138'
        }

        ufw::allow { 'https port icinga ipv6':
            proto => 'tcp',
            port  => 443,
            from  => '2001:41d0:800:105a::6'
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

    # $gluster_volume_backup = lookup('gluster_volume_backup', {'default_value' => 'glusterfs2.miraheze.org:/mvol'})
    # backup-volfile-servers=
    if !defined(Gluster::Mount['/mnt/mediawiki-static']) {
        gluster::mount { '/mnt/mediawiki-static':
          ensure    => mounted,
          volume    => lookup('gluster_volume', {'default_value' => 'gluster1.miraheze.org:/mvol'}),
        }
    }
}
