# role: elasticsearch
class role::elasticsearch {
    include ::java

    class { 'elastic_stack::repo':
        version => 6,
    }
    class { 'elasticsearch':
        version => '6.8.1',
    }

    # https://www.elastic.co/guide/en/elasticsearch/reference/master/heap-size.html
    elasticsearch::instance { 'es-01':
        jvm_options => [
            '-Xms2500M',
            '-Xmx2500M',
        ]
    }

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

    monitoring::services { 'elasticsearch-lb.miraheze.org HTTPS':
        check_command => 'check_http',
        vars          => {
            http_ssl   => true,
            http_vhost => 'elasticsearch-lb.miraheze.org',
        },
     }
 
    motd::role { 'role::elasticsearch':
        description => 'elasticsearch server',
    }
}
