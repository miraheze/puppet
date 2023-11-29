# == Configures a mcrouter instance for caching
#
# == Properties
#
class role::mediawiki::mcrouter(
    Integer      $num_proxies        = lookup('role::mediawiki::mcrouter::num_proxies', {'default_value' => 5}),
    Integer      $timeouts_until_tko = lookup('role::mediawiki::mcrouter::timeouts_until_tko', {'default_value' => 10}),
    Hash         $servers_by_dc      = lookup('role::mediawiki::mcrouter::shards')
) {

    # Server pools
    $pools = $servers_by_dc.map |$dc, $servers| {
      role::mcrouter_pools($dc, $servers, 'plain', 11211)
    }.reduce |$memo, $value| { $memo + $value }

    $routes = union(
        $servers_by_dc.map |$dc, $_| {
          {
            'aliases' => [ "/${dc}/mw/" ],
            'route' => 'PoolRoute|miraheze'
          }
        },
        # WAN cache: issues reads and add/cas/touch locally and issues set/delete everywhere.
        # MediaWiki will set a prefix of /*/mw-wan when broadcasting, explicitly matching
        # all the mw-wan routes. Broadcasting is thus completely controlled by MediaWiki,
        # but is only allowed for set/delete operations.
        $servers_by_dc.map |$dc, $_| {
          {
            'aliases' => [ "/${dc}/mw-wan/" ],
            'route'   => {
              'type'               => 'OperationSelectorRoute',
              'default_policy'     => 'PoolRoute|miraheze',
              'operation_policies' => {
                'set'    => 'PoolRoute|miraheze',
                'delete' => 'PoolRoute|miraheze',
              }
            }
          }
        },
    )

    class { 'mcrouter':
      pools                  => $pools,
      routes                 => $routes,
      region                 => 'miraheze',
      cluster                => 'mw',
      num_proxies            => $num_proxies,
      timeouts_until_tko     => $timeouts_until_tko,
      probe_delay_initial_ms => 60000,
      port                   => 11213,
    }

    file { '/etc/systemd/system/mcrouter.service.d/cpuaccounting-override.conf':
        content => "[Service]\nCPUAccounting=yes\n",
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Exec['systemd daemon-reload for mcrouter.service']
    }

    ferm::rule { 'skip_mcrouter_wancache_conntrack_out':
        desc  => 'Skip outgoing connection tracking for mcrouter',
        table => 'raw',
        chain => 'OUTPUT',
        rule  => "proto tcp sport (11213 11211) NOTRACK;",
    }

    ferm::rule { 'skip_mcrouter_wancache_conntrack_in':
        desc  => 'Skip incoming connection tracking for mcrouter',
        table => 'raw',
        chain => 'PREROUTING',
        rule  => "proto tcp dport 11213 NOTRACK;",
    }
}
