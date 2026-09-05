# = Class: role::puppetdb
#
# Sets up a Puppet DB server.
#
class role::puppetdb {

    class { 'puppetdb': }

    # Used for puppetdb
    prometheus::exporter::jmx { "puppetdb_${facts['networking']['hostname']}":
        port        => 9401,
        config_file => '/etc/puppetlabs/puppetdb/jvm_prometheus_jmx_exporter.yaml',
        content     => epp('role/puppetdb/jvm_prometheus_jmx_exporter.yaml.epp'),
        notify      => Service['puppetdb']
    }

    firewall::service { 'puppetdb port 8081':
        proto    => 'tcp',
        port     => 8081,
        src_sets => ['PUPPETSERVER_HOSTS', 'ICINGA2_HOSTS'],
    }

    system::role { 'puppetdb':
        description => 'PuppetDB server',
    }
}
