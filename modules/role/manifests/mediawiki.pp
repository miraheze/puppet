# role: mediawiki
class role::mediawiki {
    include ::mediawiki

    $strictFirewall = lookup('role::mediawiki::use_strict_firewall', {'default_value' => false})
    if $strictFirewall {
        $firewallIpv4 = query_nodes("domain='$domain' and (Class[Role::Mediawiki] or Class[Role::Varnish] or Class[Role::Services] or Class[Role::Icinga2])", 'ipaddress')
        $firewallIpv4.each |$key| {
            ufw::allow { "http port ${key}":
                proto => 'tcp',
                port  => 80,
                from  => $key,
            }

            ufw::allow { "https port ${key}":
                proto => 'tcp',
                port  => 443,
                from  => $key,
            }
        }

        $firewallIpv6 = query_nodes("domain='$domain' and (Class[Role::Mediawiki] or Class[Role::Varnish] or Class[Role::Services] or Class[Role::Icinga2])", 'ipaddress6')
        $firewallIpv6.each |$key| {
            ufw::allow { "http port ${key}":
                proto => 'tcp',
                port  => 80,
                from  => $key,
            }

            ufw::allow { "https port ${key}":
                proto => 'tcp',
                port  => 443,
                from  => $key,
            }
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
          volume    => lookup('gluster_volume', {'default_value' => 'gluster3.miraheze.org:/static'}),
        }
    }
}
