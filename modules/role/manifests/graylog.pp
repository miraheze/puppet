# role: graylog
class role::graylog {
    include ssl::wildcard

    motd::role { 'role::graylog':
        description => 'central logging server',
    }

    nginx::site { 'graylog_proxy':
        ensure  => present,
        source  => puppet:///modules/role/graylog/graylog.miraheze.org.conf'
    }

    # NOT setting ufw ports here yet!

    class { 'mongodb::globals':
        manage_package_repo => true,
    }->
    class { 'mongodb::server':
        bind_ip => ['127.0.0.1'],
    }

    class { 'elastic_stack::repo':
        version => 6,
    }

    class { 'elasticsearch':
        version      => '6.8.12',
        repo_version => '6.x',
        manage_repo  => true,
    }->
    elasticsearch::instance { 'graylog':
        config => {
            'cluster.name' => 'graylog',
            'network.host' => '127.0.0.1',
        }
    }

    class { 'graylog::repository':
        version => '3.3'
    }->
    class { 'graylog::server':
        package_version => '3.3.6-1',
        config          => {
            'password_secret'       => lookup('passwords::graylog::password_secret'),
            'root_password_sha2'    => lookup('passwords::graylog:root_password_sha2'),
        }
    }
}
