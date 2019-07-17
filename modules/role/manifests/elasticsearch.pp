# role: elasticsearch
class role::elasticsearch {
    include ::java

    class { 'elastic_stack::repo':
        version => 6,
    }

    $es_master_node = hiera('role::elasticsearch::master', false)
    $es_data_node = hiera('role::elasticsearch::data_node', false)

    class { 'elasticsearch':
        config => {
            'cluster.name' => 'Miraheze',
            'bootstrap.mlockall' => true,
            'index.number_of_shards' => 1,
            'index.number_of_replicas' => 0,
            'index.codec' => 'best_compression',
            'index.refresh_interval' => '5s',
            'node.master' => $es_master_node,
            'node.data' => $es_data_node
        },
        version => '6.8.1',
    }

    $es_heap = hiera('role::elasticsearch::data_node', ['-Xms2g', '-Xmx2g'])

    # https://www.elastic.co/guide/en/elasticsearch/reference/master/heap-size.html
    elasticsearch::instance { 'es-01':
        jvm_options => $es_heap,
        init_defaults => {
            'MAX_OPEN_FILES' => '150000',
        }
    }

    if es_master_node {
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

    motd::role { 'role::elasticsearch':
        description => 'elasticsearch server',
    }
}
