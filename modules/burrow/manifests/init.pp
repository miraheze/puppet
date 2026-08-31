# SPDX-License-Identifier: Apache-2.0
# == Define: burrow
#
# Burrow is a consumer offset lag monitoring tool for Kafka
# This module helps set up a burrow service that provides a
# http endpoint to query, and will email notifications on
# consumer groups statuses.
# This module supports only Burrow >= 1.0, since older versions are based
# on completely different configurations.
#
# == Parameters
#
# [*client_id*]
#   The client ID string to provide to Kafka when consuming
#
# [*httpserver_port*]
#   Port at which to make the burrow http endpoint available
#
# [*lagcheck_intervals*]
#   Length of window of offsets used to monitor lag
#   See: https://github.com/linkedin/Burrow/wiki/Configuration#lagcheck
#
# [*zookeeper_hosts*]
#   Array of zookeeper host and their ports.
#
# [*zookeeper_path*]
#   The full path to the znode that is the root for the Kafka cluster.
#
# [*kafka_cluster_name*]
#   Name of the Kafka cluster to monitor.
#
# [*kafka_brokers*]
#   Array of kafka brokers in the Kafka cluster.
#
# [*kafka_api_version*]
#   Kafka api version to use with the cluster.
#   Current maximum supported one is 1.0.0
#   Default: '1.0.0'
#
# [*alert_whitelist*]
#   Regex related to a whitelist of consumer groups that can trigger
#   notifications via email.
#
# [*smtp_server*]
#   SMTP server to send emails from
#
# [*from_email*]
#   From email address for notification
#
# [*to_email*]
#   Email address to send email notification to
#
# [*email_template*]
#   The name of the email template to use for Burrow's alerts
#
# [*consumer_groups_blacklist*]
#   Regex used to filter out temporary/not-relevant consumer groups.
#   Default: '^(console-consumer-|python-kafka-consumer-|test_).*$'
#
# [*kafka_brokers_port*]
#   Port used by Kafka brokers.
#   Default: 9092
#
# [*zookeeper_port*]
#   Port used by zookeeper.
#   Default: 2181
#
define burrow (
    $zookeeper_hosts,
    $zookeeper_path,
    $kafka_cluster_name,
    $kafka_brokers,
    $alert_whitelist,
    $smtp_server,
    $from_email,
    $to_email,
    $smtp_server_port = 25,
    $kafka_brokers_port = 9092,
    $zookeeper_port = 2181,
    $kafka_api_version='1.0.0',
    $client_id = 'burrow-client',
    $httpserver_port = 8000,
    $lagcheck_intervals = 10,
    $email_template = 'burrow/email.tmpl.epp',
    $consumer_groups_blacklist = '^(console-consumer-|python-kafka-consumer-|test_).*$',
)
{
    stdlib::ensure_packages('burrow')

    # Burrow 1.0 accepts one parameter named '--config-dir' that
    # expects a directory containing a file named 'burrow.toml'.
    # Since multiple instances of Burrow can run on the same hosts,
    # it is necessary to create the appropriate etc hierarchy.
    $config_dir = "/etc/burrow/${title}"
    file { $config_dir:
        ensure => 'directory',
    }

    $email_template_path = "${config_dir}/email.tmpl"
    if $to_email {
        file { $email_template_path:
            content => epp($email_template, { 'lagcheck_intervals' => $lagcheck_intervals }),
        }
    }

    file { "${config_dir}/burrow.toml":
        content => epp('burrow/burrow.toml.epp', { 'title' => $title, 'zookeeper_hosts' => $zookeeper_hosts, 'zookeeper_port' => $zookeeper_port, 'kafka_api_version' => $kafka_api_version, 'kafka_brokers' => $kafka_brokers, 'kafka_brokers_port' => $kafka_brokers_port, 'consumer_groups_blacklist' => $consumer_groups_blacklist, 'httpserver_port' => $httpserver_port, 'to_email' => $to_email, 'alert_whitelist' => $alert_whitelist, 'email_template_path' => $email_template_path, 'from_email' => $from_email, 'smtp_server' => $smtp_server, 'smtp_server_port' => $smtp_server_port }),
    }

    systemd::service { "burrow-${title}":
        ensure    => present,
        content   => systemd_template('burrow', { 'title' => $title, 'config_dir' => $config_dir }),
        restart   => true,
        subscribe => File["${config_dir}/burrow.toml"],
        require   => [
            Package['burrow'],
        ],
    }

    if ! defined(Service['burrow']) {
        service { 'burrow':
            ensure  => stopped,
            require => Package['burrow'],
        }
    }
}
