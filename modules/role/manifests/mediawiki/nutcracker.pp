# === Class role::mediawiki::nutcracker
class role::mediawiki::nutcracker (
    Array[Variant[Stdlib::Host,String]] $memcached_servers_1 = lookup('memcached_servers_1', {'default_value' => []}),
    Array[Variant[Stdlib::Host,String]] $memcached_servers_2 = lookup('memcached_servers_2', {'default_value' => []}),
) {

    if $memcached_servers_1 != [] and $memcached_servers_2 != [] {
        $nutcracker_pools = {
            'memcached_1'     => {
                auto_eject_hosts     => false,
                distribution         => 'ketama',
                hash                 => 'md5',
                listen               => '127.0.0.1:11212',
                preconnect           => true,
                server_connections   => 1,
                server_failure_limit => 3,
                server_retry_timeout => 30000,  # milliseconds
                timeout              => 250,    # milliseconds
                servers              => $memcached_servers_1,
            },
            'memcached_2'     => {
                auto_eject_hosts     => false,
                distribution         => 'ketama',
                hash                 => 'md5',
                listen               => '127.0.0.1:11213',
                preconnect           => true,
                server_connections   => 1,
                server_failure_limit => 3,
                server_retry_timeout => 30000,  # milliseconds
                timeout              => 250,    # milliseconds
                servers              => $memcached_servers_2,
            },
        }

        # Ship a tmpfiles.d configuration to create /run/nutcracker
        systemd::tmpfile { 'nutcracker':
            content => 'd /run/nutcracker 0755 nutcracker nutcracker - -'
        }

        class { '::nutcracker':
            mbuf_size => '64k',
            pools     => $nutcracker_pools,
        }

        systemd::unit { 'nutcracker':
            content  => "[Service]\nCPUAccounting=yes\n",
            override => true,
        }

        monitoring::nrpe { 'nutcracker process':
            command => '/usr/lib/nagios/plugins/check_procs -c 1:1 -u nutcracker -C nutcracker',
            docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#Nutcracker'
        }

        ferm::rule { 'skip_nutcracker_conntrack_out_1':
            desc  => 'Skip outgoing connection tracking for Nutcracker',
            table => 'raw',
            chain => 'OUTPUT',
            rule  => 'proto tcp sport (6378:6382 11212) NOTRACK;',
        }

        ferm::rule { 'skip_nutcracker_conntrack_in_1':
            desc  => 'Skip incoming connection tracking for Nutcracker',
            table => 'raw',
            chain => 'PREROUTING',
            rule  => 'proto tcp dport (6378:6382 11212) NOTRACK;',
        }

        ferm::rule { 'skip_nutcracker_conntrack_out_2':
            desc  => 'Skip outgoing connection tracking for Nutcracker',
            table => 'raw',
            chain => 'OUTPUT',
            rule  => 'proto tcp sport (6378:6382 11213) NOTRACK;',
        }

        ferm::rule { 'skip_nutcracker_conntrack_in_2':
            desc  => 'Skip incoming connection tracking for Nutcracker',
            table => 'raw',
            chain => 'PREROUTING',
            rule  => 'proto tcp dport (6378:6382 11213) NOTRACK;',
        }
    }
}
