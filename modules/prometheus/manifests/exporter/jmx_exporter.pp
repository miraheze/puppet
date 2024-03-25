# SPDX-License-Identifier: Apache-2.0
# == Define prometheus::exporter::jmx_exporter
#
# Renders a Prometheus JMX Exporter config file, declares
# a prometheus::jmx_exporter_instance so that the prometheus server
# will be configured to pull from this exporter instance,
# and installs ferm rules to allow it to do so.
# The hostname:port combination, derived from the define's parameters, will
# be used as Prometheus target (so metrics will be associated to it). This trick
# should allow the configuration of multiple Prometheus targets on the same
# machine, for use cases like Cassandra (multiple JVM instances with different
# domains on the same host) or Kafka (Kafka/MirrorMaker JVMs on the same host).
#
# Parameters:
#
#  [*hostname*]
#    Hostname used by the exporter for the listen socket.
#
#  [*port*]
#    Port used by the exporter for the listen socket.
#
#  [*config_file*]
#    The full path of the configuration file to create. Check 'config_dir' for
#    more info about how its parent directory is handled.
#
# [*config_dir*]
#   The parent directory of the jmx exporter (usually /etc/prometheus). If not
#   undef or already defined, it will be created by this profile. This is only
#   a handy way to avoid code repetition while using this profile, but special
#   care must be taken since: 1) this parameter assumes a string like
#   '/etc/$name', arbitrary nesting is not currently supported 2) the $config_file
#   value needs to be set accordingly.
#   Default: undef
#
#  [*content*]
#    Content of the exporter's configuration file. One between content or source
#    must be specified.
#
#  [*source*]
#    Source content of the exporter's configuration file. One between content or
#    source must be specified.
#
#  [*labels*]
#    Hash of any common labels to be added to all metrics exported
#    from this jmx exporter instance.  NOTE: These will take precedence over
#    labels declared in prometheus::jmx_exporter_config on the prometheus
#    server.  All jobs there automatically get a 'cluster' label applied,
#    so be careful not to override that one (unless you really mean to!)
#    Default: {}
#
define prometheus::exporter::jmx_exporter (
    Stdlib::Host               $hostname,
    Stdlib::Port               $port,
    Stdlib::Unixpath           $config_file,
    Optional[Stdlib::Unixpath] $config_dir = undef,
    Optional[String]           $content = undef,
    Optional[String]           $source  = undef,
    Optional[Hash]             $labels = {},
) {
    if $source == undef and $content == undef {
        fail('you must provide either "source" or "content"')
    }

    if $source != undef and $content != undef  {
        fail('"source" and "content" are mutually exclusive')
    }

    if !defined(File['/usr/share/java/prometheus/jmx_prometheus_javaagent.jar']) {
        file { '/usr/share/java/prometheus':
            ensure => 'directory',
            owner  => 'root',
            group  => 'root',
        }

        file { '/usr/share/java/prometheus/jmx_prometheus_javaagent.jar':
            ensure  => 'present',
            mode    => '0555',
            owner   => 'root',
            group   => 'root',
            source  => 'puppet:///modules/prometheus/jmx_exporter/jmx_prometheus_javaagent.jar',
            require => File['/usr/share/java/prometheus']
        }
    }

    if $config_dir and !defined(File[$config_dir]) {
        # Create the Prometheus JMX Exporter configuration's parent dir
        file { $config_dir:
            ensure => 'directory',
            mode   => '0444',
            owner  => 'root',
            group  => 'root',
        }
    }

    # Create the Prometheus JMX Exporter configuration
    file { $config_file:
        ensure  => 'present',
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => $content,
        source  => $source,
        # If the source is using a symlink, copy the link target, not the symlink.
        links   => 'follow',
    }

    # Allow automatic generation of config on the Prometheus master.
    prometheus::jmx_exporter_instance { $title:
        hostname => $hostname,
        port     => $port,
        labels   => $labels,
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Prometheus]', ['networking'])
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
    ferm::service { "prometheus ${port} jmx_exporter":
        proto  => 'tcp',
        port   => $port,
        srange => "(${firewall_rules_str})",
    }
}
