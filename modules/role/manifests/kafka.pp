# role: kafka
class role::kafka {
    include kafka::broker::monitoring

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

    $jmx_opts = "${kafka::broker::monitoring::jmx_opts} ${kafka::params::broker_jmx_opts}"

    class { 'kafka::broker':
        jmx_opts => $jmx_opts,
        config   => {
          # 'allow.everyone.if.no.acl.found'   => 'true',
          # 'authorizer.class.name'            => 'kafka.security.auth.SimpleAclAuthorizer',
            'auto.create.topics.enable'        => 'true',
            'auto_leader_rebalance_enable'     => 'true',
            'broker.id'                        => '0',
            'broker.id.generation.enable'      => 'false',
            'default.replication.factor'       => '1',
            'delete.topic.enable'              => 'true',
            'group.initial.rebalance.delay.ms' => '10000',
            'listeners'                        => 'PLAINTEXT://:9092',
            'log.message.timestamp.type'       => 'CreateTime',
            'log.retention.hours'              => '168', # 1 week
            'message.max.bytes'                => '4194304',
            'num.io.threads'                   => '4',
            'offsets.retention.minutes'        => '10080', # 1 week
            'offsets.topic.replication.factor' => '1',
            'replica.fetch.max.bytes'          => '4194304',
            'socket.receive.buffer.bytes'      => '1048576',
            'socket.send.buffer.bytes'         => '1048576',
            'zookeeper.connect'                => 'localhost:2181',
        }
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
