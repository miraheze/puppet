# role: kafka
class role::kafka {
    include kafka::broker::monitoring

    # We need zookeeper also
    class { 'zookeeper':
        servers             => {
            '1' => '10.0.18.159',
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

    systemd::timer::job { 'zookeeper-cleanup':
        ensure      => present,
        description => 'Regular jobs for running the cleanup script',
        user        => 'zookeeper',
        command     => '/usr/share/zookeeper/bin/zkCleanup.sh -n 10',
        environment => {
            'CLASSPATH' => '/etc/zookeeper/conf:/usr/share/java/zookeeper.jar:/usr/share/java/slf4j-log4j12.jar:/usr/share/java/log4j-1.2.jar'
        },
        interval    => {'start' => 'OnCalendar', 'interval' => '*-*-* 0:10:00'},
        require     => [Class['zookeeper'], Service['zookeeper']],
    }

    class { 'kafka':
        kafka_version => '2.4.1',
        scala_version => '2.12',
    }

    $jmx_opts = "-server -XX:MetaspaceSize=96m -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:G1HeapRegionSize=16M -XX:MinMetaspaceFreeRatio=50 -XX:MaxMetaspaceFreeRatio=80 ${kafka::broker::monitoring::jmx_opts} ${kafka::params::broker_jmx_opts}"

    file { '/var/spool/kafka':
        ensure => 'directory',
        owner  => 'kafka',
        group  => 'kafka',
        mode   => '0755',
    }

    class { 'kafka::broker':
        heap_opts    => '-Xmx2G -Xms2G',
        jmx_opts     => $jmx_opts,
        limit_nofile => '128000',
        config       => {
          # 'authorizer.class.name'             => 'kafka.security.auth.SimpleAclAuthorizer',
            'allow.everyone.if.no.acl.found'    => true,
            'auto.create.topics.enable'         => 'true',
            'auto_leader_rebalance_enable'      => 'true',
            'broker.id'                         => '0',
            'broker.id.generation.enable'       => 'false',
            'default.replication.factor'        => '1',
            'delete.topic.enable'               => 'true',
            'group.initial.rebalance.delay.ms'  => '10000',
            'listeners'                         => 'PLAINTEXT://:9092',
            'log.dirs'                          => '/var/spool/kafka',
            'log.message.timestamp.type'        => 'CreateTime',
            'log.retention.hours'               => '168', # 1 week
            'message.max.bytes'                 => '4194304',
            'num.io.threads'                    => '12',
            'num.network.threads'               => '6',
            'num.partitions'                    => '1',
            'num.recovery.threads.per.data.dir' => '4',
            'offsets.retention.minutes'         => '10080', # 1 week
            'offsets.topic.replication.factor'  => '1',
            'replica.fetch.max.bytes'           => '4194304',
            'socket.receive.buffer.bytes'       => '1048576',
            'socket.send.buffer.bytes'          => '1048576',
            'zookeeper.connect'                 => 'localhost:2181',
        }
    }

    file { '/usr/local/bin/kafka':
        source  => 'puppet:///modules/role/kafka/kafka.sh',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Class['kafka::broker'],
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
