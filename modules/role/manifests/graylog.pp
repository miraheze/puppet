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
        version             => '4.4.2',
    }->
    class { 'mongodb::server':
        bind_ip => ['127.0.0.1'],
    }

    class { 'elastic_stack::repo':
        version => 7,
    }

    class { 'elasticsearch':
        version         => '7.10.2',
        manage_repo     => true,
        config          => {
            'cluster.name'  => 'graylog',
            'http.port'     => '9200',
            'network.host'  => '127.0.0.1',
        },
        jvm_options     => ['-Xms2g', '-Xmx2g']
    }

    class { 'graylog::repository':
        version => '4.0',
    }->
    class { 'graylog::server':
        package_version => '4.0.2-1',
        config          => {
            'password_secret'       => lookup('passwords::graylog::password_secret'),
            'root_password_sha2'    => lookup('passwords::graylog::root_password_sha2'),
        }
    }

    file { '/etc/default/graylog-server':
        ensure  => 'present',
        source  => 'puppet:///role/graylog/graylog-server-default',
        owner   => 'root',
        group   => 'root',
        require => Class['graylog::server']
        notify  => Service['graylog-server']
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

    motd::role { 'role::graylog':
        description => 'central logging server',
    }
}
