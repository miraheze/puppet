# SPDX-License-Identifier: Apache-2.0
# == define role::burrow
#
# Consumer offset lag monitoring tool template for a generic Kafka cluster.
# Compatible only with burrow >= 1.0.
#
define role::burrow(
    $monitoring_config,
) {
    $config = {
      'name'      => 'main',
      'brokers'   => {
        'hash'       => brokers,
        # array of broker hostnames without port.  TODO: change this to use host:port?
        'array'      => brokers.keys.sort,
        # string list of comma-separated host:port broker
        'string'     => brokers.map { |host, conf| "#{host}:#{conf['port']}" }.sort.join(','),

        # array host:ssl_port brokers
        'ssl_array'  => brokers.map { |host, conf| "#{host}:#{conf['ssl_port']}" }.sort,
        # string list of comma-separated host:ssl_port brokers
        'ssl_string' => brokers.map { |host, conf| "#{host}:#{conf['ssl_port']}" }.sort.join(','),

        'size'       => brokers.keys.size
      },
      'jmx_port'  => jmx_port,
      'zookeeper' => {
        'name'   => zk_cluster_name,
        'hosts'  => zk_hosts,
        'chroot' => "/kafka/#{cluster_name}",
        'url'    => "#{zk_hosts.join(',')}/kafka/#{cluster_name}"
      }
    }


    burrow { 'main':
        zookeeper_hosts    => [ 'localhost' ],
        zookeeper_path     => '/kafka/main',
        kafka_cluster_name => 'main',
        kafka_brokers      => [ 'localhost' ]
        lagcheck_intervals => 100,
        httpserver_port    => 8100,
    }

    prometheus::burrow_exporter { 'main':
        burrow_addr  => 'localhost:8100',
        metrics_addr => 'localhost:9500'
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
    ferm::service { "burrow-${title}":
        proto  => 'tcp',
        port   => 8100,
        srange  => "(${firewall_rules_str})",
    }
}
