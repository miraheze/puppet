# === Class role::mediawiki::nutcracker
class role::mediawiki::nutcracker (
    Array[Variant[Stdlib::Host,String]] $redis_servers = lookup('redis_servers', {'default_value' => []}),
) {
    $nutcracker_pools = {
        'redis' => {
            auto_eject_hosts   => false,
            distribution       => 'ketama',
            hash               => 'md5',
            listen             => '/var/run/nutcracker/nutcracker.sock 0666',
            preconnect         => true,
            server_connections => 1,
            timeout            => 500,    # milliseconds
            servers            => $redis_servers,
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
        content  => "[Service]\nCPUAccounting=yes\nRestart=always\nNice=-19\n",
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
        rule  => 'proto tcp sport 11212 NOTRACK;',
    }

    ferm::rule { 'skip_nutcracker_conntrack_in':
        desc  => 'Skip incoming connection tracking for Nutcracker',
        table => 'raw',
        chain => 'PREROUTING',
        rule  => 'proto tcp dport 11212 NOTRACK;',
    }
}
