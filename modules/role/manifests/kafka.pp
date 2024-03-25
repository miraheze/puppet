# role: irc
class role::kafka {
    # We need zookeeper also
    class { 'zookeeper':
        servers             => {
            '1' => '10.0.18.146',
        },
        install_java        => true,
        java_package        => 'openjdk-17-jre-headless',
        manage_service_file => true,
        zoo_dir             => '/usr/share/zookeeper',
        log4j_prop          => 'INFO,SYSLOG',
        extra_appenders     => {
            'Syslog' => {
                'class'                    => 'org.apache.log4j.net.SyslogAppender',
                'layout'                   => 'org.apache.log4j.PatternLayout',
                'layout.conversionPattern' => "${facts['networking']['hostname']} zookeeper[id:%X{myid}] - %-5p [%t:%C{1}@%L][%x] - %m%n",
                'syslogHost'               => 'localhost',
                'facility'                 => 'user',
            },
        },
    }

    class { 'kafka':
        kafka_version => '2.4.1',
        scala_version => '2.12',
    }

    class { 'kafka::broker':
        config => {
            'auto.create.topics.enable'        => 'true',
            'broker.id'                        => '0',
            'broker.id.generation.enable'      => 'false',
            'default.replication.factor'       => '1',
            'delete.topic.enable'              => 'true',
            'offsets.topic.replication.factor' => '1',
            'zookeeper.connect'                => 'localhost:2181',
        }
    }

    prometheus::exporter::jmx { "kafka_broker_${facts['networking']['hostname']}":
        port        => 7800,
        config_file => '/etc/prometheus/kafka_broker_prometheus_jmx_exporter.yaml',
        source      => 'puppet:///modules/kafka/broker_prometheus_jmx_exporter.yaml',
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Changeprop] or Class[Role::Eventgate]', ['networking'])
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
    ferm::service { 'kafka':
        proto   => 'tcp',
        port    => '9092',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    system::role { 'kafka':
        description => 'Kafka server',
    }
}
