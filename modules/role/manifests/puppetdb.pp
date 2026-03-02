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
        content     => template('role/puppetdb/jvm_prometheus_jmx_exporter.yaml.erb'),
        notify      => Service['puppetdb']
    }

    $subquery = @("PQL")
    (resources { type = 'Class' and title = 'Role::Puppetserver' } or
    resources { type = 'Class' and title = 'Role::Icinga2' })
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)
    ferm::service { 'puppetdb port 8081':
        proto  => 'tcp',
        port   => '8081',
        srange => "(${firewall_rules_str})",
    }

    system::role { 'puppetdb':
        description => 'PuppetDB server',
    }
}
