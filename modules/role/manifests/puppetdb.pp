# = Class: role::puppetdb
#
# Sets up a Puppet DB server.
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
class role::puppetdb (
    String  $puppetdb_hostname      = lookup('puppetdb_hostname', {'default_value' => 'puppet141.miraheze.org'}),
    Boolean $puppetdb_enable        = lookup('puppetdb_enable', {'default_value' => false}),
    Integer $puppet_major_version   = lookup('puppet_major_version', {'default_value' => 7})
) {

    class { 'puppetdb': }

    file { '/etc/puppetlabs/puppetdb/logback.xml':
        ensure => present,
        source => 'puppet:///modules/role/puppetdb/puppetdb_logback.xml',
        notify => Service['puppetdb'],
    }

    rsyslog::input::file { 'puppetdb':
        path              => '/var/log/puppetlabs/puppetdb/puppetdb.log.json',
        syslog_tag_prefix => '',
        use_udp           => true,
    }

    # Used for puppetdb
    prometheus::exporter::jmx { "puppetdb_${::hostname}":
        port        => 9401,
        config_file => '/etc/puppetlabs/puppetdb/jvm_prometheus_jmx_exporter.yaml',
        content     => template('role/puppetdb/jvm_prometheus_jmx_exporter.yaml.erb'),
        notify      => Service['puppetdb']
    }

    motd::role { 'role::puppetdb':
        description => 'puppetdb',
    }
}
