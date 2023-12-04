# role: prometheus
class role::prometheus {
    include prometheus::exporter::blackbox

    $blackbox_mediawiki_urls = query_nodes('Class[Role::Varnish] or Class[Role::MediaWiki]').map |$host| {
        [ 'Miraheze', 'Special:RecentChanges' ].map |$page| {
            "https://${host}/wiki/${page}"
        }
    }
    .flatten()
    .unique()
    .sort()

    file { '/etc/prometheus/targets/blackbox_mediawiki_urls.yaml':
        ensure  => present,
        mode    => '0444',
        content => stdlib::to_yaml([{'targets' => $blackbox_mediawiki_urls.flatten}])
    }

    $blackbox_web_urls = [
        'https://phabricator.miraheze.org',
        'https://matomo.miraheze.org',
        'https://graylog.miraheze.org'
    ]

    file { '/etc/prometheus/targets/blackbox_web_urls.yaml':
        ensure  => present,
        mode    => '0444',
        content => stdlib::to_yaml([{'targets' => $blackbox_web_urls}])
    }

    $blackbox_jobs = [
        {
            'job_name' => 'blackbox/mediawiki',
            'metrics_path' => '/probe',
            'params' => {
                'module' => [ 'https_mediawiki_cp' ],
            },
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/blackbox_mediawiki_urls.yaml' ]
                }
            ],
            'relabel_configs' => [
                {
                    'source_labels' => [ '__address__' ],
                    'target_label' => '__param_target',
                },
                {
                    'source_labels' => [ '__param_target' ],
                    'target_label' => 'instance',
                },
                {
                    'target_label' => '__address__',
                    'replacement' => '127.0.0.1:9115',
                }
            ]
        },
        {
            'job_name' => 'blackbox/web',
            'metrics_path' => '/probe',
            'params' => {
                'module' => [ 'https_200_300_connect' ],
            },
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/blackbox_web_urls.yaml' ]
                }
            ],
            'relabel_configs' => [
                {
                    'source_labels' => [ '__address__' ],
                    'target_label' => '__param_target',
                },
                {
                    'source_labels' => [ '__param_target' ],
                    'target_label' => 'instance',
                },
                {
                    'target_label' => '__address__',
                    'replacement' => '127.0.0.1:9115',
                }
            ]
        }
    ]

    $cadvisor_job = [
        {
            'job_name'        => 'cadvisor',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/cadvisor.yaml' ]
                }
            ]
        }
    ]

    prometheus::class { 'cadvisor':
        dest   => '/etc/prometheus/targets/cadvisor.yaml',
        module => 'Prometheus::Exporter::Cadvisor',
        port   => 4194,
    }

    $fpm_job = [
        {
            'job_name' => 'fpm',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/fpm.yaml' ]
                }
            ]
        }
    ]

    prometheus::class { 'fpm':
        dest   => '/etc/prometheus/targets/fpm.yaml',
        module => 'Prometheus::Exporter::Fpm',
        port   => 9253
    }

    $varnish_job = [
        {
            'job_name' => 'varnish',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/varnish.yaml' ]
                }
            ]
        }
    ]

    prometheus::class { 'varnish':
        dest   => '/etc/prometheus/targets/varnish.yaml',
        module => 'Prometheus::Exporter::Varnish',
        port   => 9131
    }

    $redis_job = [
        {
            'job_name' => 'redis',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/redis.yaml' ]
                }
            ]
        }
    ]

    prometheus::class { 'redis':
        dest   => '/etc/prometheus/targets/redis.yaml',
        module => 'Prometheus::Exporter::Redis',
        port   => 9121
    }

    $mariadb_job = [
        {
            'job_name' => 'mariadb',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/mariadb.yaml' ]
                }
            ]
        }
    ]

    prometheus::class { 'mariadb':
        dest   => '/etc/prometheus/targets/mariadb.yaml',
        module => 'Prometheus::Exporter::Mariadb',
        port   => 9104
    }

    $nginx_job = [
        {
            'job_name' => 'nginx',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/nginx.yaml' ]
                }
            ]
        }
    ]

    prometheus::class { 'nginx':
        dest   => '/etc/prometheus/targets/nginx.yaml',
        module => 'Prometheus::Exporter::Nginx',
        port   => 9113
    }

    $puppetserver_job = [
        {
            'job_name' => 'puppetserver',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/puppetserver.yaml' ]
                }
            ]
        }
    ]

    # jmx based
    prometheus::class { 'puppetserver':
        dest   => '/etc/prometheus/targets/puppetserver.yaml',
        module => 'Role::Puppetserver',
        port   => 9400
    }

    $puppetdb_job = [
        {
            'job_name' => 'puppetdb',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/puppetdb.yaml' ]
                }
            ]
        }
    ]

    # jmx based
    prometheus::class { 'puppetdb':
        dest   => '/etc/prometheus/targets/puppetdb.yaml',
        module => 'Puppetdb',
        port   => 9401
    }

    $memcached_job = [
        {
            'job_name' => 'memcached',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/memcached.yaml' ]
                }
            ]
        }
    ]

    prometheus::class { 'memcached':
        dest   => '/etc/prometheus/targets/memcached.yaml',
        module => 'Prometheus::Exporter::Memcached',
        port   => 9150
    }

    $postfix_job = [
        {
            'job_name' => 'postfix',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/postfix.yaml' ]
                }
            ]
        }
    ]

    prometheus::class { 'postfix':
        dest   => '/etc/prometheus/targets/postfix.yaml',
        module => 'Prometheus::Exporter::Postfix',
        port   => 9154,
    }

    $openldap_job = [
        {
            'job_name' => 'openldap',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/openldap.yaml' ]
                }
            ]
        }
    ]

    prometheus::class { 'openldap':
        dest   => '/etc/prometheus/targets/openldap.yaml',
        module => 'Prometheus::Exporter::Openldap',
        port   => 9142
    }

    $elasticsearch_job = [
        {
            'job_name' => 'elasticsearch',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/elasticsearch.yaml' ]
                }
            ]
        }
    ]

    prometheus::class { 'elasticsearch':
        dest   => '/etc/prometheus/targets/elasticsearch.yaml',
        module => 'Prometheus::Exporter::Elasticsearch',
        port   => 9206
    }

    $statsd_exporter_job = [
      {
        'job_name'        => 'statsd_exporter',
        'scheme'          => 'http',
        'file_sd_configs' => [
          { 'files' => [ 'targets/statsd_exporter.yaml' ] },
        ],
      },
    ]

    prometheus::class{ 'statsd_exporter':
        dest   => '/etc/prometheus/targets/statsd_exporter.yaml',
        module => 'Prometheus::Exporter::Statsd_exporter',
        port   => 9112,
    }

    $global_extra = {}

    class { '::prometheus':
        global_extra => $global_extra,
        scrape_extra => [
            $blackbox_jobs, $fpm_job, $redis_job, $mariadb_job, $nginx_job,
            $puppetserver_job, $puppetdb_job, $memcached_job,
            $postfix_job, $openldap_job, $elasticsearch_job, $statsd_exporter_job,
            $varnish_job, $cadvisor_job
        ].flatten,
    }

    $firewall_grafana = join(
        query_facts("networking.domain='${facts['networking']['domain']}' and Class[Role::Grafana]", ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

    ferm::service { 'prometheus':
        proto  => 'tcp',
        port   => '9090',
        srange => "(${firewall_grafana})",
    }

    motd::role { 'role::prometheus':
        description => 'central Prometheus server',
    }
}
