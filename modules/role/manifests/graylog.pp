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
        version             => '4.4.9',
    }->
    class { 'mongodb::server':
        bind_ip => ['127.0.0.1'],
    }

    class { 'elastic_stack::repo':
        version => 7,
    }

    class { 'elasticsearch':
        version         => '7.15.0',
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
        version => '4.1',
    }->
    class { 'graylog::server':
        package_version => '4.1.6-1',
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
    $fwHttps = query_facts("domain='$domain' and (Class[Role::Mediawiki] or Class[Role::Icinga2])", ['ipaddress', 'ipaddress6'])
    $fwHttps.each |$key, $value| {
        ufw::allow { "graylog access 443/tcp for ${value['ipaddress']}":
            proto => 'tcp',
            port  => 443,
            from  => $value['ipaddress'],
        }

        ufw::allow { "graylog access 443/tcp for ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 443,
            from  => $value['ipaddress6'],
        }
    }

    # syslog-ng > graylog 12210/tcp
    # non-OpenVZ (RamNode)
    $fwSyslog = query_facts("domain='$domain' and Class[Base] and network!='127.0.0.1'", ['ipaddress', 'ipaddress6'])
    $fwSyslog.each |$key, $value| {
        ufw::allow { "graylog access 12210/tcp for ${value['ipaddress']}":
            proto => 'tcp',
            port  => 12210,
            from  => $value['ipaddress'],
        }

        ufw::allow { "graylog access 12210/tcp for ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 12210,
            from  => $value['ipaddress6'],
        }
    }

    # syslog-ng > graylog 12210/tcp
    # puppet facter returns the wrong IP addresses by default for RamNode VMs with the venet0:0 interface
    $fwSyslogVenet = query_facts("domain='$domain' and Class[Base] and network='127.0.0.1'", ['ipaddress_venet0:0', 'ipaddress6_venet0'])
    $fwSyslogVenet.each |$key, $value| {
        ufw::allow { "graylog access 12210/tcp for ${value['ipaddress_venet0:0']}":
            proto => 'tcp',
            port  => 12210,
            from  => $value['ipaddress_venet0:0'],
        }

        ufw::allow { "graylog access 12210/tcp for ${value['ipaddress6_venet0']}":
            proto => 'tcp',
            port  => 12210,
            from  => $value['ipaddress6_venet0'],
        }
    }

    $fwIcinga = query_facts("domain='$domain' and Class['Role::Icinga2'] and network!='127.0.0.1'", ['ipaddress', 'ipaddress6'])
    $fwIcinga.each |$key, $value| {
        ufw::allow { "graylog access 12201/tcp for ${value['ipaddess']}":
            proto => 'tcp',
            port  => 12201,
            from  => $value['ipaddress'],
        }

        ufw::allow { "graylog access 12201/tcp for ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 12201,
            from  => $value['ipaddress6'],
        }
    }

    motd::role { 'role::graylog':
        description => 'central logging server',
    }
}
