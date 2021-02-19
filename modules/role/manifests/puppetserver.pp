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
    String  $puppetdb_hostname      = lookup('puppetdb_hostname', {'default_value' => 'puppet3.miraheze.org'}),
    Boolean $puppetdb_enable        = lookup('puppetdb_enable', {'default_value' => false}),
    Integer $puppet_major_version   = lookup('puppet_major_version', {'default_value' => 6}),
    String  $puppetserver_hostname  = lookup('puppetserver_hostname', {'default_value' => 'puppet3.miraheze.org'}),
    String  $puppetserver_java_opts = lookup('puppetserver_java_opts', {'default_value' => '-Xms300m -Xmx300m'}),
) {

    class { '::puppetserver':
        puppetdb_hostname      => $puppetdb_hostname,
        puppetdb_enable        => $puppetdb_enable,
        puppet_major_version   => $puppet_major_version,
        puppetserver_hostname  => $puppetserver_hostname ,
        puppetserver_java_opts => $puppetserver_java_opts,
    }

    # Used for puppetdb and puppetserver
    prometheus::jmx_exporter { "puppetserver_${::hostname}":
        port        => 9400,
        config_file => '/etc/puppetlabs/puppetserver/jvm_prometheus_puppetserver_jmx_exporter.yaml',
        source      => 'puppet:///modules/role/puppetserver/jvm_prometheus_puppetserver_jmx_exporter.yaml',
        notify      => [
            Service['puppetdb'],
            Service['puppetserver']
        ]
    }

    motd::role { 'role::puppetserver':
        description => 'Centralised puppetserver',
    }
}
