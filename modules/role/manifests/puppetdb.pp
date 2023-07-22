# = Class: role::puppetdb
#
# Sets up a Puppet DB server.
#
class role::puppetdb {

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
