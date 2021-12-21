# role: graylog
class role::graylog {
    include ssl::wildcard
    include ::java

    nginx::site { 'graylog_proxy':
        ensure  => present,
        source  => 'puppet:///modules/role/graylog/graylog.miraheze.org.conf',
    }

    class { 'mongodb::globals':
        manage_package_repo => true,
        version             => '4.4.10',
    }->
    class { 'mongodb::server':
        bind_ip => ['127.0.0.1'],
    }

    class { 'elastic_stack::repo':
        version => 7,
    }

    class { 'elasticsearch':
        version         => '7.16.1',
        manage_repo     => true,
        config          => {
            'cluster.name'  => 'graylog',
            'http.port'     => '9200',
            'network.host'  => '127.0.0.1',
        },
        jvm_options     => ['-Xms2g', '-Xmx2g'],
        templates => {
            'graylog-internal' => {
                'source' => 'puppet:///modules/role/elasticsearch/index_template.json'
            }
        }
    }

    class { 'graylog::repository':
        version => '4.2',
    }->
    class { 'graylog::server':
        package_version => '4.2.4-1',
        config          => {
            'password_secret'          => lookup('passwords::graylog::password_secret'),
            'root_password_sha2'       => lookup('passwords::graylog::root_password_sha2'),
            'processbuffer_processors' => 10,
            'outputbuffer_processors'  => 6
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
        query_facts('Class[Role::Mediawiki] or Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
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
    # non-OpenVZ (RamNode)
    $firewall_syslog_rules_str = join(
        query_facts("Class[Base] and network!='127.0.0.1'", ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
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


    # syslog-ng > graylog 12210/tcp
    # puppet facter returns the wrong IP addresses by default for RamNode VMs with the venet0:0 interface
    $firewall_syslog_venet_rules_str = join(
        query_facts("Class[Base] and network='127.0.0.1'", ['ipaddress_venet0:0', 'ipaddress6_venet0'])
        .map |$key, $value| {
            "${value['ipaddress_venet0:0']} ${value['ipaddress6_venet0']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'graylog 12210 venet':
        proto  => 'tcp',
        port   => '12210',
        srange => "(${firewall_syslog_venet_rules_str})",
    }

    $firewall_icinga_rules_str = join(
        query_facts("Class['Role::Icinga2'] and network!='127.0.0.1'", ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
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

    motd::role { 'role::graylog':
        description => 'central logging server',
    }
}
