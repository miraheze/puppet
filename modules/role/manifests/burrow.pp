# SPDX-License-Identifier: Apache-2.0
# == define role::burrow
#
# Consumer offset lag monitoring tool template for a generic Kafka cluster.
# Compatible only with burrow >= 1.0.
#
class role::burrow {

    burrow { 'main':
        zookeeper_hosts    => [ 'localhost' ],
        zookeeper_path     => '/kafka/main',
        kafka_cluster_name => 'main',
        kafka_brokers      => [ 'localhost' ],
        lagcheck_intervals => 100,
        httpserver_port    => 8100,

        # Uneeded right now
        alert_whitelist    => undef,
        smtp_server        => undef,
        from_email         => undef,
        to_email           => undef,
    }

    prometheus::exporter::burrow_exporter { 'main':
        burrow_addr  => 'localhost:8100',
        metrics_addr => '0.0.0.0:9500'
    }


    # Burrow offers a HTTP REST API
    firewall::service { 'burrow-main':
        proto    => 'tcp',
        port     => 8100,
        src_sets => ['PROMETHEUS_HOSTS'],
    }

    firewall::service { 'burrow-main-exporter':
        proto    => 'tcp',
        port     => 9500,
        src_sets => ['PROMETHEUS_HOSTS'],
    }
}
