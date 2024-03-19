# SPDX-License-Identifier: Apache-2.0
# == Role: graphite::base
# Base class for setting up a graphite instance.
#
# Sets up graphite + carbon listeners, with 8 carbon listeners running on localhost
# feeding data into graphite.
# Also sets up basic icinga checks.
#
# === Parameters
#
# [*storage_dir*]
#
#   Location to store the whisper files used by graphite in
#
# [*provide_vhost*]
#
#   If enabled, configure an Apache vhost config (which is provided by a different
#   profile if running with CAS auth)
#
class profile::graphite::base(
    $storage_dir      = '/var/lib/carbon',
    $hostname         = 'graphite.wikitide.net',
    $cors_origins     = [ 'https://grafana.wikitide.net' ],
    $c_relay_settings = {},
    $cluster_servers  = lookup('role::graphite::base::cluster_servers'),
    $uwsgi_processes  = lookup('role::graphite::base::uwsgi_processes'),
    $uwsgi_max_request_duration_seconds = undef,
    $uwsgi_max_request_rss_megabytes = undef,
    $provide_vhost    = true,
) {
    $carbon_storage_dir = $storage_dir

    class { '::graphite':
        # First match wins with storage schemas
        # lint:ignore:arrow_alignment
        storage_schemas     => {
            # Retain daily metrics for 25 years. Per metric size: 109528 bytes
            'daily'     => {
                pattern    => '(^daily\..*|.*\.daily$)',
                retentions => '1d:25y',
            },
            # Retain aggregated data at 1 hour resolution for 1 year and at
            # 1 day resolution for 5 years. Per metric size: 127060 bytes
            'hourly'    => {
                pattern    => '(^hourly\..*|.*\.hourly$)',
                retentions => '1h:1y,1d:5y',
            },
            # Retain aggregated data at a one-minute resolution for one week; at
            # five-minute resolution for two weeks; at 15-minute resolution for
            # one month; one-hour resolution for one year, and 1d for five years.
            # Per metric size: 331000 bytes
            # Note that the different schemas are written to configuration file
            # in alphabetical order and matched in that order. The "default"
            # schema has to be the last one in the list, thus the "zzdefault"
            # name.
            'zzdefault' => {
                pattern    => '.*',
                retentions => '1m:7d,5m:14d,15m:30d,1h:1y,1d:5y',
            },
        },
        # lint:endignore

        # Aggregation methods for whisper files.
        # lint:ignore:arrow_alignment
        storage_aggregation => {
            'min'     => {
                pattern           => '\.min$',
                xFilesFactor      => 0.01,
                aggregationMethod => 'min',
            },
            'max'     => {
                pattern           => '\.max$',
                xFilesFactor      => 0.01,
                aggregationMethod => 'max',
            },
            'count'   => {
                pattern           => '\.count$',
                xFilesFactor      => 0,
                aggregationMethod => 'sum',
            },
            'sum'     => {
                pattern           => '\.sum$',
                xFilesFactor      => 0,
                aggregationMethod => 'sum',
            },
            # statsite extended counters
            'lower'   => {
                pattern           => '\.lower$',
                xFilesFactor      => 0.01,
                aggregationMethod => 'min',
            },
            'upper'   => {
                pattern           => '\.upper$',
                xFilesFactor      => 0.01,
                aggregationMethod => 'max',
            },
            # Like storage_schemas, this hash is written in order in the
            # configuration file and read in order by graphite
            # (lib/carbon/storage.py). Therefore put default as last item for
            # matching to work correctly.
            'zzdefault' => {
                pattern      => '.*',
                xFilesFactor => 0.01,
            },
        },
        # lint:endignore

        # All metric data goes through a single carbon-relay instance, which
        # forwards each data point to one of eight carbon-cache instances, using
        # a consistent hash ring to distribute the load.
        #
        # Why is this necessary? Because carbon-cache is CPU-bound, and the Python
        # GIL prevents it from utilizing multiple processor cores efficiently.
        #
        # cf. "Single node, multiple carbon-caches"
        # <http://bitprophet.org/blog/2013/03/07/graphite/>
        #
        # If we need to scale up, the next step is multi-node.
        # <http://tinyurl.com/graphite-cluster-setup>.
        carbon_settings     => {
            'cache'   => {
                line_receiver_interface            => '127.0.0.1',  # Only the relay binds to 0.0.0.0.
                pickle_receiver_interface          => '127.0.0.1',
                max_cache_size                     => 'inf',
                max_creates_per_minute             => '100',
                max_updates_per_second_on_shutdown => '1000',
            },

            ## Carbon caches ##

            'cache:a' => {
                line_receiver_port   => 2103,
                pickle_receiver_port => 2104,
                cache_query_port     => 7102,
            },

            ## Carbon relay ##

            'relay'   => {
                pickle_receiver_interface => '0.0.0.0',
                # disabled, see ::graphite::carbon_c_relay
                line_receiver_port        => '0',
                relay_method              => 'consistent-hashing',
                max_queue_size            => '500000',
                destinations              => [
                    '127.0.0.1:2104:a',
                    '127.0.0.1:2204:b',
                    '127.0.0.1:2304:c',
                    '127.0.0.1:2404:d',
                    '127.0.0.1:2504:e',
                    '127.0.0.1:2604:f',
                    '127.0.0.1:2704:g',
                    '127.0.0.1:2804:h',
                ],
            },
        },

        storage_dir         => $carbon_storage_dir,
        whisper_lock_writes => true,
        c_relay_settings    => $c_relay_settings,
    }

    class { 'graphite::web':
        admin_user                         => lookup('passwords::graphite::user'),
        admin_pass                         => lookup('passwords::graphite::pass'),
        remote_user_auth                   => true,
        secret_key                         => lookup('passwords::graphite::secret_key'),
        storage_dir                        => $carbon_storage_dir,
        documentation_url                  => '//meta.miraheze.org/wiki/Tech::Graphite',
        cluster_servers                    => $cluster_servers,
        cors_origins                       => $cors_origins,
        uwsgi_max_request_duration_seconds => $uwsgi_max_request_duration_seconds,
        uwsgi_max_request_rss_megabytes    => $uwsgi_max_request_rss_megabytes,
        uwsgi_processes                    => $uwsgi_processes,
    }

    if $provide_vhost {
        nginx::site { $hostname:
            content => template('role/graphite/graphite.nginx.erb'),
        }
    }

    ferm::service { 'graphite-http':
        proto => 'tcp',
        port  => 80,
    }

    # TODO add graphite_render and graphite_api monitoring
}
