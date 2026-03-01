# role: graylog
class role::graylog {
    include ::java

    ssl::wildcard { 'graylog wildcard': }

    nginx::site { 'graylog_proxy':
        ensure => present,
        source => 'puppet:///modules/role/graylog/logging.wikitide.net.conf',
    }

    class { 'mongodb::globals':
        manage_package_repo => true,
        repo_version        => lookup('mongodb_repo_version', {'default_value' => '8.0'}),
        version             => lookup('mongodb_version', {'default_value' => '8.0.18'}),
    }
    -> class { 'mongodb::server':
        bind_ip => ['127.0.0.1'],
    }

    $elasticsearch_host = lookup('elasticsearch_host', {'default_value' => 'http://localhost:9200'})
    $http_proxy = lookup('http_proxy', {'default_value' => undef})
    class { 'graylog::repository':
        proxy   => $http_proxy,
        version => '7.0',
    }
    -> class { 'graylog::server':
        package_version        => '7.0.4-1',
        config                 => {
            'password_secret'           => lookup('passwords::graylog::password_secret'),
            'root_password_sha2'        => lookup('passwords::graylog::root_password_sha2'),
            'elasticsearch_hosts'       => $elasticsearch_host,
            'ignore_migration_failures' => true,
            'telemetry_enabled'         => false,
        },
        java_initial_heap_size => '3g',
        java_max_heap_size     => '3g'
    }

    # Access is restricted: https://meta.miraheze.org/wiki/Tech:Graylog#Access
    $subquery = @("PQL")
    (resources { type = 'Class' and title = 'Role::Bastion' } or
    resources { type = 'Class' and title = 'Role::Mediawiki' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_beta' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_task' }
    resources { type = 'Class' and title = 'Role::Icinga2' }
    resources { type = 'Class' and title = 'Role::Prometheus' })
    | PQL
    $firewall_http_rules_str = vmlib::generate_firewall_ip($subquery)
    ferm::service { 'access graylog 443':
        proto  => 'tcp',
        port   => '443',
        srange => "(${firewall_http_rules_str})",
    }

    # syslog-ng > graylog 12210/tcp
    $subquery_2 = @("PQL")
    resources { type = 'Class' and title = 'Base' }
    | PQL
    $firewall_syslog_rules_str = vmlib::generate_firewall_ip($subquery_2)
    ferm::service { 'graylog 12210':
        proto  => 'tcp',
        port   => '12210',
        srange => "(${firewall_syslog_rules_str})",
    }

    $subquery_3 = @("PQL")
    resources { type = 'Class' and title = 'Role::Icinga2' }
    | PQL
    $firewall_icinga_rules_str = vmlib::generate_firewall_ip($subquery_3)
    ferm::service { 'graylog 12201':
        proto  => 'tcp',
        port   => '12201',
        srange => "(${firewall_icinga_rules_str})",
    }

    rsyslog::input::file { 'graylog':
        path              => '/var/log/graylog-server/server.log',
        syslog_tag_prefix => '',
        use_udp           => true,
    }

    monitoring::nrpe { 'graylog tls port 12210 ssl cert check':
        command => '/usr/lib/nagios/plugins/check_tcp -H localhost -p 12210 -D 15,7',
    }

    system::role { 'graylog':
        description => 'central logging server',
    }
}
