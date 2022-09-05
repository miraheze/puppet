# role: elasticsearch
class role::elasticsearch {
    include ::java
    include prometheus::exporter::elasticsearch

    class { 'elastic_stack::repo':
        version => 7,
    }

    $es_master = hiera('role::elasticsearch::master', false)
    $es_data = hiera('role::elasticsearch::data', false)
    $es_discovery = hiera('role::elasticsearch::discovery_host', false)

    class { 'elasticsearch':
        config      => {
            'discovery.seed_hosts'                           => $es_discovery,
            'cluster.name'                                   => 'miraheze-general',
            'node.master'                                    => $es_master,
            'node.data'                                      => $es_data,
            'network.host'                                   => $::fqdn,
            'xpack.security.enabled'                         => true,
            'xpack.security.http.ssl.enabled'                => true,
            'xpack.security.http.ssl.key'                    => '/etc/elasticsearch/ssl/wildcard.miraheze.org-2020-2.key',
            'xpack.security.http.ssl.certificate'            => '/etc/elasticsearch/ssl/wildcard.miraheze.org-2020-2.crt',
            'xpack.security.transport.ssl.enabled'           => true,
            'xpack.security.transport.ssl.key'               => '/etc/elasticsearch/ssl/wildcard.miraheze.org-2020-2.key',
            'xpack.security.transport.ssl.certificate'       => '/etc/elasticsearch/ssl/wildcard.miraheze.org-2020-2.crt',
            'xpack.security.transport.ssl.verification_mode' => 'certificate',
            # We use a firewall so this is safe
            'xpack.security.authc.anonymous.username'        => 'elastic',
            'xpack.security.authc.anonymous.roles'           => 'superuser',
            'xpack.security.authc.anonymous.authz_exception' => true,
        },
        version     => '7.10.2',
        manage_repo => true,
        jvm_options => [ '-Xms2g', '-Xmx2g' ],
        templates   => {
            'graylog-internal' => {
                'source' => 'puppet:///modules/role/elasticsearch/index_template.json'
            }
        }
    }

    file { '/etc/elasticsearch/ssl':
        ensure => directory,
    }

    ssl::wildcard { 'elasticsearch wildcard':
        ssl_cert_path             => '/etc/elasticsearch/ssl/',
        ssl_cert_key_private_path => '/etc/elasticsearch/ssl',
    }

    if $es_master {
        nginx::site { 'elasticsearch.miraheze.org':
            ensure  => present,
            source  => 'puppet:///modules/role/elasticsearch/nginx.conf',
            monitor => false,
        }

        $firewall_rules_str = join(
            query_facts('Class[Role::Mediawiki] or Class[Role::Icinga2] or Class[Role::Graylog] or Class[Role::Elasticsearch]', ['ipaddress6'])
            .map |$key, $value| {
                $value['ipaddress6']
            }
            .flatten()
            .unique()
            .sort(),
            ' '
        )

        ferm::service { 'elasticsearch ssl':
            proto  => 'tcp',
            port   => '443',
            srange => "(${firewall_rules_str})",
        }
    }

    $firewall_es_nodes = join(
        query_facts('Class[Role::Elasticsearch]', ['ipaddress6'])
        .map |$key, $value| {
            $value['ipaddress6']
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'elasticsearch data nodes to master':
        proto  => 'tcp',
        port   => '9200',
        srange => "(${firewall_es_nodes})",
    }

    ferm::service { 'elasticsearch master access data nodes 9200 port':
        proto  => 'tcp',
        port   => '9300',
        srange => "(${firewall_es_nodes})",
    }

    motd::role { 'role::elasticsearch':
        description => 'elasticsearch server',
    }
}
