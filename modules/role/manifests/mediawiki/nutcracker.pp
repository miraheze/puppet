# === Class role::mediawiki::nutcracker
class role::mediawiki::nutcracker (
    Hash $memcached_servers = lookup('memcached_servers', {'default_value' => undef}),
) {

    if $memcached_servers != undef {
        $nutcracker_pools = {
            $memcached_servers.each |String $pool_name, Hash $pool_data| {
                $pool_name => {
                    auto_eject_hosts     => false,
                    distribution         => 'ketama',
                    hash                 => 'md5',
                    listen               => "127.0.0.1:${pool_data['port']}",
                    preconnect           => true,
                    server_connections   => 1,
                    server_failure_limit => 3,
                    server_retry_timeout => 30000, # milliseconds
                    timeout              => 500,   # milliseconds
                    servers              => $pool_data['server'],
                },
            }
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
