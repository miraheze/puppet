# role: elasticsearch
class role::elasticsearch {
    include ::java

    class { 'elastic_stack::repo':
        version => 6,
    }

    $es_master_node = hiera('role::elasticsearch::master', false)
    $es_data_node = hiera('role::elasticsearch::data_node', false)
    $es_unicast_host = hiera('role::elasticsearch::unicast_host', '127.0.0.1')

    class { 'elasticsearch':
        config => {
            'bootstrap.memory_lock' => false,
            
            'discovery.zen.ping.unicast.hosts' => $es_unicast_host,
            'cluster.name' => 'Miraheze',
            'node.master' => $es_master_node,
            'node.data' => $es_data_node,
            'network.bind_host' => '0.0.0.0',
            'network.publish_host' => '0.0.0.0',
        },
        version => '6.8.1',
    }

    $es_instance = hiera('role::elasticsearch::instance', 'es-01')
    $es_jvm_options = hiera('role::elasticsearch::jvm_options', ['-Xms2g', '-Xmx2g', '-Des.enforce.bootstrap.checks=true'])

    # https://www.elastic.co/guide/en/elasticsearch/reference/master/heap-size.html
    elasticsearch::instance { $es_instance:
        jvm_options => $es_jvm_options,
        init_defaults => {
            'MAX_OPEN_FILES' => '1500000',
        }
    }

    if $es_master_node {
        include ssl::wildcard

        nginx::site { 'elasticsearch-lb.miraheze.org':
            ensure      => present,
            source      => 'puppet:///modules/role/elasticsearch/nginx-site.conf',
            monitor     => false,
            notify_site => Exec['nginx-syntax'],
        }

        exec { 'nginx-syntax':
            command     => '/usr/sbin/nginx -t',
            notify      => Exec['nginx-reload'],
            refreshonly => true,
        }

        exec { 'nginx-reload':
            command     => '/usr/sbin/service nginx reload',
            refreshonly => true,
            require     => Exec['nginx-syntax'],
        }

        ufw::allow { 'nginx port misc1':
            proto => 'tcp',
            port  => '443',
            from  => '185.52.1.76',
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

    # TODO: Switch this to use https
    ufw::allow { 'elasticsearch master access data nodes 9300 port':
        proto => 'tcp',
        port  => '9300',
        from  => hiera('role::elasticsearch::master_ip')
    }
    motd::role { 'role::elasticsearch':
        description => 'elasticsearch server',
    }
}
