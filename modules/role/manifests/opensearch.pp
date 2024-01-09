# role: opensearch
class role::opensearch (
    $os_master = lookup('role::opensearch::master', {'default_value' => false}),
    $os_data = lookup('role::opensearch::data', {'default_value' => false}),
    $os_discovery = lookup('role::opensearch::discovery_host', {'default_value' => false}),
    $os_master_hosts = lookup('role::opensearch::master_hosts', {'default_value' => undef}),
) {
    include ::java

    class { 'opensearch::repo':
        version => '2.x',
    }

    class { 'opensearch':
        config      => {
            'cluster.initial_master_nodes'                          => $os_master_hosts,
            'discovery.seed_hosts'                                  => $os_discovery,
            'cluster.name'                                          => 'miraheze-general',
            'node.master'                                           => $os_master,
            'node.data'                                             => $os_data,
            'network.host'                                          => $facts['networking']['fqdn'],
            'plugins.security.ssl.http.enabled'                     => true,
            'plugins.security.ssl.http.pemkey_filepath'             => '/etc/opensearch/ssl/opensearch-node-key.pem',
            'plugins.security.ssl.http.pemcert_filepath'            => '/etc/opensearch/ssl/opensearch-node.crt',
            'plugins.security.ssl.http.pemtrustedcas_filepath'      => '/etc/opensearch/ssl/opensearch-ca.pem',
            'plugins.security.ssl.transport.pemkey_filepath'        => '/etc/opensearch/ssl/opensearch-node-key.pem',
            'plugins.security.ssl.transport.pemcert_filepath'       => '/etc/opensearch/ssl/opensearch-node.crt',
            'plugins.security.ssl.transport.pemtrustedcas_filepath' => '/etc/opensearch/ssl/opensearch-ca.pem',
            'plugins.security.ssl_cert_reload_enabled'              => true,
            # TODO: Admin must use its own certificate.
            'plugins.security.authcz.admin_dn'                      => ['CN=ADMIN_MIRAHEZE,O=Miraheze LTD,L=Worksop,ST=Nottinghamshire,C=GB'],
            'plugins.security.nodes_dn'                             => ['CN=*.miraheze.org'],
            'plugins.security.restapi.roles_enabled'                => ['all_access', 'security_rest_api_access'],
        },
        version     => '2.11.0',
        manage_repo => true,
        jvm_options => [ '-Xms2g', '-Xmx2g' ],
        templates   => {
            'graylog-internal' => {
                'source' => 'puppet:///modules/role/opensearch/index_template.json'
            }
        }
    }

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

    # We only need to do this on the main node.
    if ($os_master) {
        File['/etc/opensearch/opensearch-security/config.yml'] ~> Exec['run opensearch-security']
        File['/etc/opensearch/opensearch-security/roles_mapping.yml'] ~> Exec['run opensearch-security']
        File['/etc/opensearch/opensearch-security/roles.yml'] ~> Exec['run opensearch-security']
    }

    exec { 'run opensearch-security':
        command     => '/usr/local/bin/opensearch-security',
        refreshonly => true,
        require     => File['/usr/local/bin/opensearch-security']
    }

    if $os_master {
        # For nginx
        ssl::wildcard { 'opensearch wildcard': }

        nginx::site { 'opensearch.miraheze.org':
            ensure  => present,
            source  => 'puppet:///modules/role/opensearch/nginx.conf',
            monitor => false,
        }

        $firewall_rules_str = join(
            query_facts("Class[Role::Mediawiki] or Class[Role::Icinga2] or Class[Role::Graylog] or Class[Role::Opensearch]", ['networking'])
            .map |$key, $value| {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
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

    if $os_master {
        include prometheus::exporter::elasticsearch
    }

    $firewall_os_nodes = join(
        query_facts("Class[Role::Opensearch]", ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'opensearch data nodes to master':
        proto  => 'tcp',
        port   => '9200',
        srange => "(${firewall_os_nodes})",
    }

    ferm::service { 'opensearch master access data nodes 9200 port':
        proto  => 'tcp',
        port   => '9300',
        srange => "(${firewall_os_nodes})",
    }

    motd::role { 'role::opensearch':
        description => 'opensearch server',
    }
}
