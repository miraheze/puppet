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

        # Temporarily to test ats (apache traffic server)
        ufw::allow { 'http port 80 51.195.236.214':
            proto => 'tcp',
            port  => 80,
            from  => '51.195.236.214',
        }

        ufw::allow { 'https port 80 2001:41d0:800:178a::12':
            proto => 'tcp',
            port  => 80,
            from  => '2001:41d0:800:178a::12',
        }

        ufw::allow { 'http port 443 51.195.236.214':
            proto => 'tcp',
            port  => 443,
            from  => '51.195.236.214',
        }

        ufw::allow { 'https port 443 2001:41d0:800:178a::12':
            proto => 'tcp',
            port  => 443,
            from  => '2001:41d0:800:178a::12',
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

    file { '/usr/local/bin/remountGluster.sh':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/role/mediawiki/bin/remountGluster.sh',
    }

    cron { 'check_mount':
        ensure  => present,
        command => '/bin/bash /usr/local/bin/remountGluster.sh',
        user    => 'root',
        minute  => '*/1',
        hour    => '*',
    }
}
