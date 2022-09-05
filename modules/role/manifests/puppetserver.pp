# = Class: role::puppetserver
#
# Sets up a centralised puppetserver.
#
# = Parameters
#
# [*puppetdb_hostname*]
#   The hostname for puppetdb server.
#
# [*puppetdb_enable*]
#   A boolean on whether to enable puppetdb for the centralised puppetserver.
#
# [*puppet_major_version*]
#   A integer for the version of puppetserver you want installed.
#
# [*puppetserver_hostname*]
#   The hostname for the centralised puppetserver.
#
# [*puppetserver_java_opts*]
#   Options for java (which runs the puppetserver)
#
class role::puppetserver (
    String  $puppetdb_hostname      = lookup('puppetdb_hostname', {'default_value' => 'puppet141.miraheze.org'}),
    Boolean $puppetdb_enable        = lookup('puppetdb_enable', {'default_value' => false}),
    Integer $puppet_major_version   = lookup('puppet_major_version', {'default_value' => 7}),
    String  $puppetserver_hostname  = lookup('puppetserver_hostname', {'default_value' => 'puppet141.miraheze.org'}),
    String  $puppetserver_java_options = lookup('puppetserver_java_opts', {'default_value' => '-Xms300m -Xmx300m'}),
) {

    $puppetserver_java_opts = "${puppetserver_java_options} -javaagent:/usr/share/java/prometheus/jmx_prometheus_javaagent.jar=${::fqdn}:9400:/etc/puppetlabs/puppetserver/jvm_prometheus_jmx_exporter.yaml"
    class { '::puppetserver':
        puppetdb_hostname      => $puppetdb_hostname,
        puppetdb_enable        => $puppetdb_enable,
        puppet_major_version   => $puppet_major_version,
        puppetserver_hostname  => $puppetserver_hostname ,
        puppetserver_java_opts => $puppetserver_java_opts,
    }

    # Used for puppetserver
    prometheus::exporter::jmx { "puppetserver_${::hostname}":
        port        => 9400,
        config_file => '/etc/puppetlabs/puppetserver/jvm_prometheus_jmx_exporter.yaml',
        content     => template('role/puppetserver/jvm_prometheus_jmx_exporter.yaml.erb'),
        notify      => Service['puppetserver']
    }

    # Used for puppetdb
    prometheus::exporter::jmx { "puppetdb_${::hostname}":
        port        => 9401,
        config_file => '/etc/puppetlabs/puppetdb/jvm_prometheus_jmx_exporter.yaml',
        content     => template('role/puppetdb/jvm_prometheus_jmx_exporter.yaml.erb'),
        notify      => Service['puppetdb']
    }

    motd::role { 'role::puppetserver':
        description => 'Centralised puppetserver',
    }
}
