# role: graylog
class role::graylog {
    include ssl::wildcard
    include ::java

    nginx::site { 'graylog_proxy':
        ensure  => present,
        source  => 'puppet:///modules/role/graylog/graylog.miraheze.org.conf',
    }

    # NOT setting ufw ports here yet!

    class { 'mongodb::globals':
        manage_package_repo => true,
        version             => '4.2.11',
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
        package_version => '4.0.0-1',
        config          => {
            'password_secret'       => lookup('passwords::graylog::password_secret'),
            'root_password_sha2'    => lookup('passwords::graylog::root_password_sha2'),
        }
    }

    motd::role { 'role::graylog':
        description => 'central logging server',
    }
}
