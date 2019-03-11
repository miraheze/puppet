# role: elasticsearch
class role::elasticsearch {
    include ::java

    class { 'elastic_stack::repo':
        version => 5,
    }
    class { 'elasticsearch':
        version => '5.6.15',
    }

    # https://www.elastic.co/guide/en/elasticsearch/reference/master/heap-size.html
    elasticsearch::instance { 'es-01':
        jvm_options => [
            '-Xms512m',
            '-Xmx512m',
        ]
    }

    include ssl::wildcard

    nginx::site { 'elasticsearch-lb.miraheze.org':
        ensure      => present,
        source      => 'puppet:///modules/role/elasticsearch/nginx-site.conf',
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

    motd::role { 'role::elasticsearch':
        description => 'elasticsearch server',
    }
}
