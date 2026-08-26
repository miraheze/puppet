function network::host_group(String[1] $set_name) >> Array[String[1]] {
    $classes_by_set = {
        'ICINGA2_HOSTS'          => 'Role::Icinga2',
        'ALL_HOSTS'              => 'Base',
        'BASTION_HOSTS'          => 'Role::Bastion',
        'MEDIAWIKI_HOSTS'        => 'Role::Mediawiki',
        'MEDIAWIKI_TASK_HOSTS'   => 'Role::Mediawiki_task',
        'MEDIAWIKI_BETA_HOSTS'   => 'Role::Mediawiki_beta',
        'VARNISH_HOSTS'          => 'Role::Varnish',
        'CACHE_CACHE_HOSTS'      => 'Role::Cache::Cache',
        'CACHE_VARNISH_HOSTS'    => 'Role::Cache::Varnish',
        'PROMETHEUS_HOSTS'       => 'Role::Prometheus',
        'PROMETHEUS_CLASS_HOSTS' => 'Prometheus',
        'GRAFANA_HOSTS'          => 'Role::Grafana',
        'GRAYLOG_HOSTS'          => 'Role::Graylog',
        'LLM_HOSTS'              => 'Role::Llm',
        'MATOMO_HOSTS'           => 'Role::Matomo',
        'OPENLDAP_HOSTS'         => 'Role::Openldap',
        'DB_HOSTS'               => 'Role::Db',
        'PHORGE_HOSTS'           => 'Role::Phorge',
        'REPORTS_HOSTS'          => 'Role::Reports',
        'PUPPETSERVER_HOSTS'     => 'Role::Puppetserver',
        'CLOUD_HOSTS'            => 'Role::Cloud',
        'CHANGEPROP_HOSTS'       => 'Role::Changeprop',
        'EVENTGATE_HOSTS'        => 'Role::Eventgate',
        'SWIFT_HOSTS'            => 'Role::Swift',
        'MATTERMOST_HOSTS'       => 'Role::Mattermost',
        'OPENSEARCH_HOSTS'       => 'Role::Opensearch',
    }

    if !($set_name in $classes_by_set) {
        fail("network::host_group: unknown set '${set_name}' - add it to modules/network/functions/host_group.pp")
    }

    network::hosts_with_class($classes_by_set[$set_name])
}
