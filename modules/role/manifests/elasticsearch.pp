# role: elasticsearch
class role::elasticsearch {
    include ::java

    class { 'elasticsearch': }
    # https://www.elastic.co/guide/en/elasticsearch/reference/master/heap-size.html
    elasticsearch::instance { 'es-01':
        jvm_options => [
            '-Xms512m',
            '-Xmx512m',
        ]
    }

    motd::role { 'role::elasticsearch':
        description => 'elasticsearch server',
    }
}
