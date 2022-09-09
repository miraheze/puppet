# === Class role::mediawiki::nutcracker
class role::mediawiki::nutcracker (
    Hash $nutcracker_config = lookup('role::mediawiki::nutcracker::config', {'default_value' => undef}),
) {
    if $nutcracker_config != undef {
        $nutcracker_pools = {
            $nutcracker_config.each |String $pool_name, Hash $pool_data| {
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
                    servers              => $pool_data['servers'],
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

        $nutcracker_config.each |String $pool_name, Hash $pool_data| {
            ferm::rule { "skip_nutcracker_conntrack_out_${pool_name}":
                desc  => 'Skip outgoing connection tracking for Nutcracker',
                table => 'raw',
                chain => 'OUTPUT',
                rule  => "proto tcp sport (6378:6382 ${pool_data['port']}) NOTRACK;",
            }

            ferm::rule { "skip_nutcracker_conntrack_in_${pool_name}":
                desc  => 'Skip incoming connection tracking for Nutcracker',
                table => 'raw',
                chain => 'PREROUTING',
                rule  => "proto tcp dport (6378:6382 ${pool_data['port']}) NOTRACK;",
            }
        }
    }
}
