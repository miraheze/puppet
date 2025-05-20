# Class: kafka::broker::monitoring
#
# Sets up Prometheus based monitoring and icinga alerts.
class kafka::broker::monitoring {
    $prometheus_jmx_exporter_port = 7800
    $config_dir                   = '/etc/prometheus'
    $jmx_exporter_config_file     = "${config_dir}/kafka_broker_prometheus_jmx_exporter.yaml"

    # Use this in your JAVA_OPTS you pass to the Kafka  broker process
    $jmx_opts = "-javaagent:/usr/share/java/prometheus/jmx_prometheus_javaagent.jar=${facts['networking']['fqdn']}:${prometheus_jmx_exporter_port}:${jmx_exporter_config_file}"

    # Declare a prometheus jmx_exporter instance.
    # This will render the config file, declare the jmx_exporter_instance,
    # and configure ferm.
    prometheus::exporter::jmx_exporter { "kafka_broker_${facts['networking']['hostname']}":
        hostname    => $facts['networking']['hostname'],
        port        => $prometheus_jmx_exporter_port,
        labels      => {'kafka_cluster' => 'default'},
        config_file => $jmx_exporter_config_file,
        config_dir  => $config_dir,
        source      => 'puppet:///modules/kafka/broker_prometheus_jmx_exporter.yaml',
    }

    ### Icinga alerts
    # Generate icinga alert if Kafka Broker Server is not running.
    monitoring::nrpe { 'Kafka Broker Server':
        command => '/usr/lib/nagios/plugins/check_procs -c 1:1 -C java -a "Kafka /opt/kafka/config/server.properties"',
    }
}

