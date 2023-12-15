# SPDX-License-Identifier: Apache-2.0
# == Class: mcrouter
#
# mcrouter is a fast routing proxy for memcached.
# It can reduce the connection count on the backend caching servers
# and also supports layered pools, replication, and key/operation
# based routing to pools.
#
# === Parameters
#
# [*pools*]
#   A hash defining a mcrouter server pool.
#   See <https://github.com/facebook/mcrouter/wiki/Config-Files>.
#
# [*routes*]
#   A list of hashes that define route handles.
#   See <https://github.com/facebook/mcrouter/wiki/List-of-Route-Handles>.
#
# [*region*]
#   Datacenter name for the one in this geographical region
#
# [*cluster*]
#   Memcached cluster name
#
# [*cross_region_timeout_ms*]
#   Timeout, in milliseconds, when performing cross-region memcached operations
#
# [*cross_cluster_timeout_ms*]
#   Timeout, in milliseconds, when performing cross-cluster memcached operations
#
# [*num_proxies*]
#   Maximum number of connections to each backend. Defaults to 1.
#
# [*probe_delay_initial_ms*]
#   TKO probe retry initial timeout in ms. When a memcached server is marked
#   as TKO (by default after 3 timeouts registered), mcrouter waits this amount
#   of time before sending the first health checks probes (meant to verify
#   the status of memcached before sending traffic again).
#   Defaults to 3000.
#
# [*timeouts_until_tko*]
#   Number of timeouts to happen before marking a memcached server as TKO.
#   Default: undef
#
# === Examples
#
#  class { '::mcrouter':
#    region                   => $::site,
#    cluster                  => 'clustername',
#    cross_region_timeout_ms  => 250,
#    cross_cluster_timeout_ms => 1000,
#    pools                    => {
#      'clustername-main' => {
#        servers => [ '10.68.23.25:11211', '10.68.23.49:11211' ]
# #                       ^ note that these must be IPs, not fqdns
#      }
#    },
#    routes                   => [ {
#      aliases => [ "/${::site}/clustername" ],
#      route   => {
#        type => 'OperationSelectorRoute',
#        default_policy => 'PoolRoute|clustername-main',
#        operation_policies => {
#          set => 'AllFastestRoute|Pool|clustername-main',
#          delete => 'AllFastestRoute|Pool|clustername-main'
#        }
#      }
#    } ]
#  }
#
class mcrouter(
    Hash              $pools,
    Array             $routes,
    String            $region,
    String            $cluster,
    VMlib::Ensure    $ensure                   = present,
    Stdlib::Port      $port                     = 11213,
    Integer           $cross_region_timeout_ms  = 500,
    Integer           $cross_cluster_timeout_ms = 1000,
    Integer           $num_proxies              = 2,
    Integer           $probe_delay_initial_ms   = 3000,
    Optional[Integer] $timeouts_until_tko       = undef,
) {

    if ($facts['os']['distro']['codename'] == 'bullseye') {
        stdlib::ensure_packages(['libboost-filesystem1.74.0', 'libboost-regex1.74.0-icu67', 'libevent-2.1-7', 'libfmt7', 'libgoogle-glog0v5', 'libjemalloc2'])

        file { '/opt/mcrouter_2022.01.31.00-1_amd64.deb':
            ensure  => present,
            source => 'puppet:///private/mcrouter/mcrouter_2022.01.31.00-1_amd64.deb',
            require => [
                Package['libboost-filesystem1.74.0'],
                Package['libboost-regex1.74.0-icu67'],
                Package['libevent-2.1-7'],
                Package['libfmt7'],
                Package['libgoogle-glog0v5'],
                Package['libjemalloc2']
            ]
        }
    
        package { 'mcrouter':
            ensure      => installed,
            provider    => dpkg,
            source      => '/opt/mcrouter_2022.01.31.00-1_amd64.deb',
            require     => File['/opt/mcrouter_2022.01.31.00-1_amd64.deb'],
        }
    } else {
        stdlib::ensure_packages(['libboost-context1.74.0', 'libboost-filesystem1.74.0', 'libboost-program-options1.74.0', 'libjemalloc2', 'libboost-regex1.74.0-icu72', 'libfmt9', 'libgflags2.2', 'libgoogle-glog0v6'])

        file { '/opt/mcrouter_2023.07.17.00-1_amd64.deb':
            ensure  => present,
            source => 'puppet:///private/mcrouter/mcrouter_2023.07.17.00-1_amd64.deb',
            require => [
                Package['libboost-context1.74.0'],
                Package['libboost-filesystem1.74.0'],
                Package['libboost-program-options1.74.0'],
                Package['libjemalloc2'],
                Package['libboost-regex1.74.0-icu72'],
                Package['libfmt9'],
                Package['libgflags2.2'],
                Package['libgoogle-glog0v6']
            ]
        }
    
        package { 'mcrouter':
            ensure      => installed,
            provider    => dpkg,
            source      => '/opt/mcrouter_2023.07.17.00-1_amd64.deb',
            require     => File['/opt/mcrouter_2023.07.17.00-1_amd64.deb'],
        }
    }

    $config = { 'pools' => $pools, 'routes' => $routes }

    file { '/etc/mcrouter/config.json':
        ensure       => $ensure,
        content      => to_json_pretty($config),
        owner        => 'root',
        group        => 'root',
        mode         => '0444',
        require      => Package['mcrouter'],
        validate_cmd => "/usr/bin/mcrouter --validate-config --port ${port} --route-prefix ${region}/${cluster} --config file:%",
    }

    file { '/etc/default/mcrouter':
        ensure  => $ensure,
        content => template('mcrouter/default.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
    }

    systemd::service { 'mcrouter':
        ensure   => $ensure,
        content  => "[Service]\nLimitNOFILE=64000\nUser=mcrouter\nNice=-19\n",
        override => true,
        restart  => false,
    }

    # Logging management
    logrotate::conf { 'mcrouter':
        ensure => present,
        source => 'puppet:///modules/mcrouter/mcrouter.logrotate.conf',
    }

    rsyslog::conf { 'mcrouter':
        source   => 'puppet:///modules/mcrouter/mcrouter.rsyslog.conf',
        priority => 20,
        require  => File['/etc/logrotate.d/mcrouter'],
        before   => Service['mcrouter'],
    }
}
