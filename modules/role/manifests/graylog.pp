# role: graylog
class role::graylog {
    include ::java
    include prometheus::exporter::graylog

    ssl::wildcard { 'graylog wildcard': }

    nginx::site { 'graylog_proxy':
        ensure => present,
        source => 'puppet:///modules/role/graylog/graylog.miraheze.org.conf',
    }

    class { 'mongodb::globals':
        manage_package_repo => true,
        version             => '5.0.21' ,
    }
    -> class { 'mongodb::server':
        bind_ip => ['127.0.0.1'],
    }

    $elasticsearch_host = lookup('elasticsearch_host', {'default_value' => 'http://localhost:9200'})
    $http_proxy = lookup('http_proxy', {'default_value' => undef})
    class { 'graylog::repository':
        proxy   => $http_proxy,
        version => '5.1',
    }
    -> class { 'graylog::server':
        package_version => '5.1.4-1',
        config          => {
            'password_secret'     => lookup('passwords::graylog::password_secret'),
            'root_password_sha2'  => lookup('passwords::graylog::root_password_sha2'),
            'elasticsearch_hosts' => $elasticsearch_host,
            'ignore_migration_failures' => true,
        }
    }

    file { '/etc/default/graylog-server':
        ensure  => 'present',
        source  => 'puppet:///modules/role/graylog/graylog-server-default',
        owner   => 'root',
        group   => 'root',
        require => Class['graylog::server'],
    }

    # Access is restricted: https://meta.miraheze.org/wiki/Tech:Graylog#Access
    $firewall_http_rules_str = join(
        query_facts("networking.domain='${facts['networking']['domain']}' and Class[Role::Bastion] or Class[Role::Mediawiki] or Class[Role::Icinga2] or Class[Role::Prometheus]", ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'access graylog 443':
        proto  => 'tcp',
        port   => '443',
        srange => "(${firewall_http_rules_str})",
    }

    # syslog-ng > graylog 12210/tcp
    $firewall_syslog_rules_str = join(
        query_facts("networking.domain='${facts['networking']['domain']}' and Class[Base]", ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'graylog 12210':
        proto  => 'tcp',
        port   => '12210',
        srange => "(${firewall_syslog_rules_str})",
    }


    $firewall_icinga_rules_str = join(
        query_facts("networking.domain='${facts['networking']['domain']}' and Class[Role::Icinga2]", ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
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

    motd::role { 'role::graylog':
        description => 'central logging server',
    }
}
