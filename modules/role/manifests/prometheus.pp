# role: prometheus
class role::prometheus {
    include prometheus::exporter::blackbox

    $blackbox_web_urls = [
        'https://issue-tracker.miraheze.org',
        'https://analytics.wikitide.net',
        'https://logging.wikitide.net'
    ]

    file { '/etc/prometheus/targets/blackbox_web_urls.yaml':
        ensure  => present,
        mode    => '0444',
        content => stdlib::to_yaml([{'targets' => $blackbox_web_urls}])
    }

    $blackbox_jobs = [
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

    $pushgateway_job = [
        {
            'job_name'        => 'pushgateway',
            'honor_labels'    => true,
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/pushgateway.yaml' ]
                },
            ],
        },
    ]

    prometheus::class { 'pushgateway':
        dest   => '/etc/prometheus/targets/pushgateway.yaml',
        module => 'Prometheus::Pushgateway',
        port   => 9091,
    }

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

    $cache_haproxy_job = [
        {
            'job_name' => 'cache_haproxy',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/cache_haproxy.yaml' ]
                }
            ]
        }
    ]

    prometheus::class { 'cache_haproxy':
        dest   => '/etc/prometheus/targets/cache_haproxy.yaml',
        module => 'Role::Cache::Haproxy',
        port   => 9422
    }

    $apache_job = [
        {
            'job_name' => 'apache',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/apache.yaml' ]
                }
            ]
        }
    ]

    prometheus::class { 'apache':
        dest   => '/etc/prometheus/targets/apache.yaml',
        module => 'Prometheus::Exporter::Apache',
        port   => 9117
    }

    $cloudflare_job = [
        {
            'job_name' => 'cloudflare',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/cloudflare.yaml' ]
                }
            ]
        }
    ]

    prometheus::class { 'cloudflare':
        dest   => '/etc/prometheus/targets/cloudflare.yaml',
        module => 'Prometheus::Exporter::Cloudflare',
        port   => 9119
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


    $kafka_job = [
        {
            'job_name'        => 'kafka',
            'scheme'          => 'http',
            'scrape_timeout'  => '45s',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/kafka.yaml' ]
                }
            ],
        },
    ]

    # Collect all declared kafka.* jmx_exporter_instances
    # from any uses of kafka::broker::monitoring.
    prometheus::jmx_exporter_config { 'kafka':
        dest              => '/etc/prometheus/targets/kafka.yaml',
        class_name        => 'kafka::broker::monitoring',
        instance_selector => 'kafka.*',
    }

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

    $kafka_burrow_jobs = [
      {
        'job_name'        => 'burrow',
        'scheme'          => 'http',
        'file_sd_configs' => [
          { 'files' => [ 'targets/burrow_*.yaml' ]}
        ],
      },
    ]

    prometheus::class{ 'burrow_main':
        dest   => '/etc/prometheus/targets/burrow_main.yaml',
        module => 'Role::Burrow',
        port   => 9500,
    }

    $eventgate_job = [
        {
            'job_name' => 'eventgate',
            'file_sd_configs' => [
                {
                    'files' => [ 'targets/eventgate.yaml' ]
                }
            ]
        }
    ]

    prometheus::class { 'eventgate':
        dest   => '/etc/prometheus/targets/eventgate.yaml',
        module => 'Role::Eventgate',
        port   => 9102
    }

    $global_extra = {}

    class { 'prometheus':
        global_extra => $global_extra,
        scrape_extra => [
            $blackbox_jobs, $fpm_job, $redis_job, $mariadb_job, $nginx_job,
            $apache_job, $puppetserver_job, $puppetdb_job, $memcached_job,
            $openldap_job, $elasticsearch_job, $statsd_exporter_job,
            $varnish_job, $cadvisor_job, $pushgateway_job, $kafka_job,
            $eventgate_job, $kafka_burrow_jobs, $cloudflare_job, $cache_haproxy_job
        ].flatten,
    }

    $firewall_grafana = join(
        query_facts('Class[Role::Grafana]', ['networking'])
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

    ferm::service { 'prometheus':
        proto  => 'tcp',
        port   => '9090',
        srange => "(${firewall_grafana})",
    }

    system::role { 'prometheus':
        description => 'central Prometheus server',
    }
}
