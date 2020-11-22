# role: graylog
class role::graylog {
    include ssl::wildcard
    include ::java

    # NOT setting ufw ports here yet!

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
        version         => '7.10.0',
        manage_repo     => true,
        config          => {
            'cluster.name'  => 'graylog',
            'http.port'     => '9200',
            'network.host'  => '127.0.0.1',
        },
    }

    class { 'graylog::repository':
        version => '4.0',
    }->
    class { 'graylog::server':
        package_version => '4.0.0-8',
        config          => {
            'password_secret'       => lookup('passwords::graylog::password_secret'),
            'root_password_sha2'    => lookup('passwords::graylog::root_password_sha2'),
            'http_bind_address'     => 'localhost:8007',
            'http_publish_uri'      => 'https://localhost:8007/',
            'http_enable_tls'       => true,
            'http_tls_cert_file'    => '/etc/ssl/certs/wildcard.miraheze.org-2020.crt',
            'http_tls_key_file'     => '/etc/ssl/private/wildcard.miraheze.org-2020.key',
        }
    }

    motd::role { 'role::graylog':
        description => 'central logging server',
    }
}
