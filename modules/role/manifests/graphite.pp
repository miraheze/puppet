# SPDX-License-Identifier: Apache-2.0
# == Role: graphite
#
# Set up graphite instance for production.
# Also includes icinga checks for anomalies for MediaWiki, EL & Swift metrics
# Instance requires people to authenticate via LDAP before they can see metrics.
#
class role::graphite {
    $storage_dir = '/srv/carbon'

    class { 'role::graphite::base':
        storage_dir                        => $storage_dir,
        uwsgi_max_request_duration_seconds => 60,
        uwsgi_max_request_rss_megabytes    => 1024,
        provide_vhost                      => false,
        c_relay_settings                   => {
            forward_clusters => {
                'default'   => [
                  'graphite151.wikitide.net:1903',
                ],
                'big_users' => [
                  'graphite151.wikitide.net:1903',
                ]
            },
            cluster_routes   => [
                ['big_users'],
            ],
            'queue_depth'    => 500000,
            'batch_size'     => 8000,
        },
    }

    file { '/var/lib/carbon':
        ensure  => directory,
    }

    file { '/var/lib/carbon/whisper':
        ensure  => link,
        target  => "${storage_dir}/whisper",
        owner   => '_graphite',
        group   => '_graphite',
        require => Class['role::graphite::base']
    }

    # General cleanup of metric files not updated. ~3y
    graphite::whisper_cleanup { 'graphite-stale-metrics':
        directory => "${storage_dir}/whisper",
        keep_days => 1024,
    }

    include rsync::server

    rsync::server::module { 'carbon':
        path => $storage_dir,
        uid  => '_graphite',
        gid  => '_graphite',
    }

    $graphite_hosts = join(
        query_facts('Class[Role::Graphite]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

    $firewall_srange = join(
        query_facts('Class[Base]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

    ferm::service { 'carbon_c_relay-local_relay_udp':
        proto  => 'udp',
        port   => '1903',
        srange => "(${graphite_hosts})",
    }

    ferm::service { 'carbon_c_relay-local_relay_tcp':
        proto  => 'tcp',
        port   => 1903,
        srange => "(${graphite_hosts})",
    }

    ferm::service { 'carbon_c_relay-frontend_relay_udp':
        proto   => 'udp',
        port    => 2003,
        srange => "(${firewall_srange})",
    }

    ferm::service { 'carbon_c_relay-frontend_relay_tcp':
        proto   => 'tcp',
        port    => 2003,
        srange => "(${firewall_srange})",
    }

    ferm::service { 'carbon_pickled':
        proto   => 'tcp',
        port    => 2004,
        srange => "(${firewall_srange})",
    }

    system::role { 'graphite':
        description => 'Real-time metrics processor',
    }
}
