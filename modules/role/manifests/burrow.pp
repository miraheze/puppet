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
    }

    prometheus::exporter::burrow_exporter { 'main':
        burrow_addr  => 'localhost:8100',
        metrics_addr => '0.0.0.0:9500'
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Prometheus]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['he-ipv6'] ) {
                "${value['networking']['ip']} ${value['networking']['interfaces']['he-ipv6']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
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

    # Burrow offers a HTTP REST API
    ferm::service { 'burrow-main':
        proto  => 'tcp',
        port   => 8100,
        srange  => "(${firewall_rules_str})",
    }
}
