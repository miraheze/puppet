# === Class role::mediawiki::nutcracker
class role::mediawiki::nutcracker (
    Array[Variant[Stdlib::Host,String]] $memcached_servers_1 = lookup('memcached_servers_1', {'default_value' => []}),
    Array[Variant[Stdlib::Host,String]] $memcached_servers_3 = lookup('memcached_servers_3', {'default_value' => []}),
    Array[Variant[Stdlib::Host,String]] $memcached_servers_test = lookup('memcached_servers_test', {'default_value' => []}),
) {

    if $memcached_servers_1 != [] and $memcached_servers_3 != [] {
        $nutcracker_pools = {
            'memcached_1'     => {
                auto_eject_hosts     => false,
                distribution         => 'ketama',
                hash                 => 'md5',
                listen               => '127.0.0.1:11212',
                preconnect           => true,
                server_connections   => 1,
                timeout              => 1000,    # milliseconds
                servers              => $memcached_servers_1,
            },
            'memcached_3'     => {
                auto_eject_hosts     => false,
                distribution         => 'ketama',
                hash                 => 'md5',
                listen               => '127.0.0.1:11214',
                preconnect           => true,
                server_connections   => 1,
                timeout              => 1000,    # milliseconds
                servers              => $memcached_servers_3,
            },
            'memcached_test'     => {
                auto_eject_hosts     => false,
                distribution         => 'ketama',
                hash                 => 'md5',
                listen               => '127.0.0.1:11215',
                preconnect           => true,
                server_connections   => 1,
                timeout              => 1000,    # milliseconds
                servers              => $memcached_servers_test,
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
            content  => "[Service]\nCPUAccounting=yes\nRestart=always\n",
            override => true,
        }

        monitoring::nrpe { 'nutcracker process':
            command => '/usr/lib/nagios/plugins/check_procs -c 1:1 -u nutcracker -C nutcracker',
            docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#Nutcracker'
        }

        ferm::rule { 'skip_nutcracker_conntrack_out':
            desc  => 'Skip outgoing connection tracking for Nutcracker',
            table => 'raw',
            chain => 'OUTPUT',
            rule  => 'proto tcp sport (11212) NOTRACK;',
        }

        ferm::rule { 'skip_nutcracker_conntrack_in':
            desc  => 'Skip incoming connection tracking for Nutcracker',
            table => 'raw',
            chain => 'PREROUTING',
            rule  => 'proto tcp dport (11212) NOTRACK;',
        }
    }
}
