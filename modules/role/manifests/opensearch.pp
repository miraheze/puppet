# role: opensearch
class role::opensearch (
    $os_roles = lookup('role::opensearch::roles', {'default_value' => []}),
    $os_discovery = lookup('role::opensearch::discovery_host', {'default_value' => false}),
    $os_manager_hosts = lookup('role::opensearch::manager_hosts', {'default_value' => undef}),
    $use_tls = lookup('role::opensearch::use_tls', {'default_value' => false}),
    $enable_exporter = lookup('role::opensearch::enable_exporter', {'default_value' => true}),
) {
    include java

    class { 'opensearch::repo':
        version => '2.x',
    }

    if $use_tls {
        $tls_config = {
            'plugins.security.ssl.http.enabled'                     => true,
            'plugins.security.ssl.http.pemkey_filepath'             => '/etc/opensearch/ssl/opensearch-node-key.pem',
            'plugins.security.ssl.http.pemcert_filepath'            => '/etc/opensearch/ssl/opensearch-node.crt',
            'plugins.security.ssl.http.pemtrustedcas_filepath'      => '/etc/opensearch/ssl/opensearch-ca.pem',
            'plugins.security.ssl.transport.pemkey_filepath'        => '/etc/opensearch/ssl/opensearch-node-key.pem',
            'plugins.security.ssl.transport.pemcert_filepath'       => '/etc/opensearch/ssl/opensearch-node.crt',
            'plugins.security.ssl.transport.pemtrustedcas_filepath' => '/etc/opensearch/ssl/opensearch-ca.pem',
            'plugins.security.ssl_cert_reload_enabled'              => true,
            # TODO: Admin must use its own certificate.
            'plugins.security.authcz.admin_dn'                      => ['CN=ADMIN_WIKITIDE,O=WikiTide Foundation,L=Washington,ST=DC,C=US'],
            'plugins.security.nodes_dn'                             => ['CN=*.wikitide.net'],
            'plugins.security.restapi.roles_enabled'                => ['all_access', 'security_rest_api_access'],
        }
    } else {
        $tls_config = {
            'plugins.security.disabled' => true
        }
    }

    class { 'opensearch':
        file_rolling_type             => 'dailyRollingFile',
        rolling_file_max_backup_index => 7,
        config                        => {
            'cluster.initial_cluster_manager_nodes' => $os_manager_hosts,
            'discovery.seed_hosts'                  => $os_discovery,
            'cluster.name'                          => 'wikitide-general',
            'node.roles'                            => $os_roles,
            'network.host'                          => '0.0.0.0',
        } + $tls_config,
        version                       => '2.19.1',
        manage_repo                   => true,
        jvm_options                   => [ '-Xms4g', '-Xmx4g' ],
        templates                     => {
            'graylog-internal' => {
                'source' => 'puppet:///modules/role/opensearch/index_template.json'
            }
        }
    }

    if $use_tls {
        file { '/etc/opensearch/ssl':
            ensure  => directory,
            owner   => 'opensearch',
            group   => 'opensearch',
            require => File['/etc/opensearch']
        }

        file { '/etc/opensearch/ssl/opensearch-ca.pem':
            ensure  => 'present',
            source  => 'puppet:///ssl/ca/opensearch-ca.pem',
            owner   => 'opensearch',
            group   => 'opensearch',
            before  => Service['opensearch'],
            require => File['/etc/opensearch/ssl'],
        }

        file { '/etc/opensearch/ssl/opensearch-node.crt':
            ensure  => 'present',
            source  => 'puppet:///ssl/certificates/opensearch-node.crt',
            owner   => 'opensearch',
            group   => 'opensearch',
            before  => Service['opensearch'],
            require => File['/etc/opensearch/ssl'],
        }

        file { '/etc/opensearch/ssl/opensearch-node-key.pem':
            ensure    => 'present',
            source    => 'puppet:///ssl-keys/opensearch-node-key.pem',
            owner     => 'opensearch',
            group     => 'opensearch',
            mode      => '0660',
            show_diff => false,
            before    => Service['opensearch'],
            require   => File['/etc/opensearch/ssl'],
        }

        file { '/etc/opensearch/ssl/opensearch-admin-cert.pem':
            ensure  => 'present',
            source  => 'puppet:///ssl/certificates/opensearch-admin-cert.pem',
            owner   => 'opensearch',
            group   => 'opensearch',
            before  => Service['opensearch'],
            require => File['/etc/opensearch/ssl'],
        }

        file { '/etc/opensearch/ssl/opensearch-admin-key.pem':
            ensure    => 'present',
            source    => 'puppet:///ssl-keys/opensearch-admin-key.pem',
            owner     => 'opensearch',
            group     => 'opensearch',
            mode      => '0660',
            show_diff => false,
            before    => Service['opensearch'],
            require   => File['/etc/opensearch/ssl'],
        }

        # Contains everything needed to update the opensearch security index
        # to apply any config changes to the index.
        # This is required to be run everytime the config changes.
        file { '/usr/local/bin/opensearch-security':
            ensure  => present,
            mode    => '0755',
            content => template('role/opensearch/bin/opensearch-security.sh.erb'),
        }

        file { '/usr/local/bin/opensearch-generate-admin-certificate.sh':
            ensure => present,
            mode   => '0755',
            source => 'puppet:///modules/role/opensearch/opensearch-generate-admin-certificate.sh'
        }

        [
            '/etc/opensearch/esnode.pem',
            '/etc/opensearch/esnode-key.pem',
            '/etc/opensearch/kirk.pem',
            '/etc/opensearch/kirk-key.pem',
            '/etc/opensearch/root-ca.pem'
        ].each |$name| {
            # Package installs demo certs by default which opensearch
            # doesn't like unless a config is set which we don't want to set.
            # Remove these files.
            file { $name:
                ensure => absent,
                notify => Service['opensearch']
            }
        }

        file {
            default:
                require => Package['opensearch'],
                owner   => 'opensearch',
                group   => 'opensearch';
            '/etc/opensearch/opensearch-security/config.yml':
                ensure => present,
                source => 'puppet:///modules/role/opensearch/config.yml';
            '/etc/opensearch/opensearch-security/roles_mapping.yml':
                ensure => present,
                source => 'puppet:///modules/role/opensearch/roles_mapping.yml';
            '/etc/opensearch/opensearch-security/roles.yml':
                ensure => present,
                source => 'puppet:///modules/role/opensearch/roles.yml';
        }
    }

    # We only need to do this on the manager node.
    if (('cluster_manager' in $os_roles) and $use_tls) {
        File['/etc/opensearch/opensearch-security/config.yml'] ~> Exec['run opensearch-security']
        File['/etc/opensearch/opensearch-security/roles_mapping.yml'] ~> Exec['run opensearch-security']
        File['/etc/opensearch/opensearch-security/roles.yml'] ~> Exec['run opensearch-security']

        exec { 'run opensearch-security':
            command     => '/usr/local/bin/opensearch-security',
            refreshonly => true,
            require     => File['/usr/local/bin/opensearch-security']
        }
    }

    if ('cluster_manager' in $os_roles) {
        nginx::site { 'opensearch.wikitide.net':
            ensure  => present,
            content => template('role/opensearch/nginx.conf.erb'),
            monitor => false,
        }

        ssl::wildcard { 'opensearch wildcard': }

        $firewall_rules_str = join(
            query_facts('Class[Role::Mediawiki] or Class[Role::Mediawiki_task] or Class[Role::Mediawiki_beta] or Class[Role::Icinga2] or Class[Role::Graylog] or Class[Role::Opensearch]', ['networking'])
            .map |$key, $value| {
                if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                    "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
                } elsif ( $value['networking']['interfaces']['ens18'] ) {
                    "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
                } else {
                    "${value['networking']['ip']} ${value['networking']['ip6']}"
                }
            }
            .flatten()
            .unique()
            .sort(),
            ' '
        )
        ferm::service { 'opensearch ssl':
            proto  => 'tcp',
            port   => '443',
            srange => "(${firewall_rules_str})",
        }
    }

    if (('cluster_manager' in $os_roles) and $enable_exporter) {
        include prometheus::exporter::elasticsearch
    }

    $firewall_os_nodes = join(
        query_facts('Class[Role::Opensearch]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'opensearch data nodes to manager':
        proto  => 'tcp',
        port   => '9200',
        srange => "(${firewall_os_nodes})",
    }

    ferm::service { 'opensearch manager access data nodes 9300 port':
        proto  => 'tcp',
        port   => '9300',
        srange => "(${firewall_os_nodes})",
    }

    system::role { 'opensearch':
        description => 'OpenSearch server',
    }
}
