# role: elasticsearch
class role::elasticsearch {
    include ::java

    class { 'elastic_stack::repo':
        version => 6,
    }

    $es_master_node = hiera('role::elasticsearch::master', false)
    $es_data_node = hiera('role::elasticsearch::data_node', false)
    $es_discovery_host = hiera('role::elasticsearch::discovery_host', ['es1.miraheze.org'])
    $es_instance = hiera('role::elasticsearch::instance', 'es-01')

    class { 'elasticsearch':
        config => {
            'discovery.zen.ping.unicast.hosts' => $es_discovery_host,
            'cluster.name' => 'Miraheze',
            'node.master' => $es_master_node,
            'node.data' => $es_data_node,
            'network.host' => $::fqdn,
            'network.bind_host' => '0.0.0.0',
            'network.publish_host' => '0.0.0.0',
            'xpack.security.enabled' => true,
            'xpack.security.http.ssl.enabled' => true,
            'xpack.security.http.ssl.key' => "/etc/elasticsearch/${es_instance}/ssl/wildcard.miraheze.org.key",
            'xpack.security.http.ssl.certificate' => "/etc/elasticsearch/${es_instance}/ssl/wildcard.miraheze.org.crt",
            'xpack.security.transport.ssl.enabled' => true,
            'xpack.security.transport.ssl.key' => "/etc/elasticsearch/${es_instance}/ssl/wildcard.miraheze.org.key",
            'xpack.security.transport.ssl.certificate' => "/etc/elasticsearch/${es_instance}/ssl/wildcard.miraheze.org.crt",
            'xpack.security.transport.ssl.verification_mode' => 'certificate',
            # We use a firewall so this is safe
            'xpack.security.authc.anonymous.username' => 'elastic',
            'xpack.security.authc.anonymous.roles' => 'superuser',
            'xpack.security.authc.anonymous.authz_exception' => true,
        },
        version => '6.8.1',
    }

    $es_heap = hiera('role::elasticsearch::heap', ['-Xms2g', '-Xmx2g'])

    # https://www.elastic.co/guide/en/elasticsearch/reference/master/heap-size.html
    elasticsearch::instance { $es_instance:
        jvm_options => $es_heap,
        init_defaults => {
            'MAX_OPEN_FILES' => '1500000',
        }
    }

    file { "/etc/elasticsearch/${es_instance}/ssl":
        ensure  => 'directory',
        mode    => '0745',
        require => Elasticsearch::Instance[$es_instance],
    }

    class { 'ssl::wildcard':
        ssl_cert_path => "/etc/elasticsearch/${es_instance}/ssl",
        ssl_cert_key_private_path => "/etc/elasticsearch/${es_instance}/ssl",
        use_globalsign => true,
        require => File["/etc/elasticsearch/${es_instance}/ssl"],
    }

    if $es_master_node {
        nginx::site { 'elasticsearch-lb.miraheze.org':
            ensure  => present,
            content => template('role/elasticsearch/nginx-site.conf.erb'),
            monitor => false,
        }

        ufw::allow { 'nginx port mw1':
            proto => 'tcp',
            port  => '443',
            from  => '185.52.1.75',
        }

        ufw::allow { 'nginx port mw2':
            proto => 'tcp',
            port  => '443',
            from  => '185.52.2.113',
        }

        ufw::allow { 'nginx port mw3':
            proto => 'tcp',
            port  => '443',
            from  => '81.4.121.113',
        }

        ufw::allow { 'nginx port test1':
            proto => 'tcp',
            port  => '443',
            from  => '185.52.2.243',
        }
    }

    ufw::allow { 'elasticsearch data nodes access master node 9300 port (1)':
        proto => 'tcp',
        port  => '9300',
        from  => '168.235.110.49',
    }

    ufw::allow { 'elasticsearch data nodes access master node 9300 port (2)':
        proto => 'tcp',
        port  => '9300',
        from  => '168.235.110.25',
    }

    ufw::allow { 'elasticsearch data nodes access master node 9300 port (3)':
        proto => 'tcp',
        port  => '9300',
        from  => '168.235.110.7',
    }

    if $es_data_node {
        ufw::allow { 'elasticsearch master access data nodes 9300 port':
            proto => 'tcp',
            port  => '9300',
            from  => hiera('role::elasticsearch::master_ip')
        }
    }

    sysctl::parameters { 'disable ipv6':
        values   => {
            # Increase TCP max buffer size
            'net.ipv6.conf.all.disable_ipv6' => 1,
            'net.ipv6.conf.default.disable_ipv6' => 1,
            'net.ipv6.conf.lo.disable_ipv6' => 1,
        },
        priority => 60,
    }
 
    motd::role { 'role::elasticsearch':
        description => 'elasticsearch server',
    }
}
