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
            'broker.id'         => '0',
            'zookeeper.connect' => 'localhost:2181'
        }
    }

    system::role { 'kafka':
        description => 'Kafka server',
    }
}
