# role: graylog
class role::graylog {
    include ::java
    include prometheus::exporter::graylog

    ssl::wildcard { 'graylog wildcard': }

    nginx::site { 'graylog_proxy':
        ensure => present,
        source => 'puppet:///modules/role/graylog/logging.wikitide.net.conf',
    }

    class { 'mongodb::globals':
        manage_package_repo => true,
        version             => lookup('mongodb_version', {'default_value' => '5.0.21'}),
    }
    -> class { 'mongodb::server':
        bind_ip => ['127.0.0.1'],
    }

    $elasticsearch_host = lookup('elasticsearch_host', {'default_value' => 'http://localhost:9200'})
    $http_proxy = lookup('http_proxy', {'default_value' => undef})
    class { 'graylog::repository':
        proxy   => $http_proxy,
        version => '5.2',
    }
    -> class { 'graylog::server':
        package_version        => '5.2.3-1',
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
    $firewall_http_rules_str = join(
        query_facts('Class[Role::Bastion] or Class[Role::Mediawiki] or Class[Role::Icinga2] or Class[Role::Prometheus]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['he-ipv6'] ) {
                "${value['networking']['ip']} ${value['networking']['interfaces']['he-ipv6']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
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
        query_facts('Class[Base]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['he-ipv6'] ) {
                "${value['networking']['ip']} ${value['networking']['interfaces']['he-ipv6']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
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
        query_facts('Class[Role::Icinga2]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['he-ipv6'] ) {
                "${value['networking']['ip']} ${value['networking']['interfaces']['he-ipv6']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
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

    system::role { 'graylog':
        description => 'central logging server',
    }
}
