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
    prometheus::exporter::jmx { "puppetdb_${facts['networking']['hostname']}":
        port        => 9401,
        config_file => '/etc/puppetlabs/puppetdb/jvm_prometheus_jmx_exporter.yaml',
        content     => template('role/puppetdb/jvm_prometheus_jmx_exporter.yaml.erb'),
        notify      => Service['puppetdb']
    }

    $firewall_rules_str = join(
        query_facts("networking.domain='${facts['networking']['domain']}' and (Class[Role::Puppetserver] or Class[Role::Icinga2])", ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'puppetdb port 8081':
        proto  => 'tcp',
        port   => '8081',
        srange => "(${firewall_rules_str})",
    }

    motd::role { 'role::puppetdb':
        description => 'puppetdb',
    }
}
