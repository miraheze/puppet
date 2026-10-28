# = Class: role::puppetserver
#
# Sets up a centralized openvox server.
#
# = Parameters
#
# [*puppetdb_hostname*]
#   The hostname for openvoxdb server.
#
# [*puppetdb_enable*]
#   A boolean on whether to enable openvoxdb for the centralized openvox server.
#
# [*openvox_major_version*]
#   A integer for the version of openvox-server you want installed.
#
# [*puppetserver_hostname*]
#   The hostname for the centralized openvox server.
#
# [*puppetserver_java_opts*]
#   Options for java (which runs the openvox server)
#
class role::puppetserver (
    String  $puppetdb_hostname         = lookup('puppetdb_hostname'),
    Boolean $puppetdb_enable           = lookup('puppetdb_enable', {'default_value' => false}),
    Integer $openvox_major_version     = lookup('openvox_major_version'),
    String  $puppetserver_hostname     = lookup('puppetserver_hostname'),
    String  $puppetserver_java_options = lookup('puppetserver_java_opts', {'default_value' => '-Xms300m -Xmx300m'}),
) {

    $puppetserver_java_opts = "${puppetserver_java_options} -javaagent:/usr/share/java/prometheus/jmx_prometheus_javaagent.jar=0.0.0.0:9400:/etc/puppetlabs/puppetserver/jvm_prometheus_jmx_exporter.yaml"
    class { '::puppetserver':
        puppetdb_hostname      => $puppetdb_hostname,
        puppetdb_enable        => $puppetdb_enable,
        openvox_major_version  => $openvox_major_version,
        puppetserver_hostname  => $puppetserver_hostname ,
        puppetserver_java_opts => $puppetserver_java_opts,
    }

    # Used for puppetserver
    prometheus::exporter::jmx { "puppetserver_${facts['networking']['hostname']}":
        port        => 9400,
        config_file => '/etc/puppetlabs/puppetserver/jvm_prometheus_jmx_exporter.yaml',
        content     => epp('role/puppetserver/jvm_prometheus_jmx_exporter.yaml.epp'),
        notify      => Service['puppetserver']
    }

    system::role { 'puppetserver':
        description => 'Puppet master!',
    }
}
