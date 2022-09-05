# class: prometheus
class prometheus (
    Hash $global_extra = {},
    Array $scrape_extra = [],
    Integer $port = 9100
) {

    ensure_packages('prometheus')

    file { '/etc/default/prometheus':
        source  => 'puppet:///modules/prometheus/prometheus.default.conf',
        owner   => 'root',
        group   => 'root',
        notify  => Service['prometheus'],
        require => Package['prometheus'],
    }

    file { '/etc/prometheus/targets':
        ensure => directory
    }

    $global_default = {
        'scrape_interval' => '15s',
        'scrape_timeout' => '15s',
    }
    $global_config = merge($global_default, $global_extra)

    $scrape_default = [
        {
            'job_name' => 'prometheus',
            'scrape_interval' => '30s',
            'scrape_timeout' => '30s',
            'static_configs' => [
                {
                    'targets' => [
                        'localhost:9090'
                    ],
                }
            ]
        },
        {
            'job_name' => 'node',
            'file_sd_configs' => [
                {
                    'files' => [
                        '/etc/prometheus/targets/nodes.yaml'
                    ]
                }
            ]
        }
    ]
    $scrape_config = concat($scrape_extra, $scrape_default)

    $common_config = {
        'global' => $global_config,
        'rule_files' => [],
        'scrape_configs' => $scrape_config
    }

    file { '/etc/prometheus/prometheus.yml':
        content => to_yaml($common_config),
        notify  => Exec['prometheus-reload']
    }

    exec { 'prometheus-reload':
        command     => '/bin/systemctl reload prometheus',
        refreshonly => true,
    }

    $servers = query_nodes('Class[Base]')
              .flatten()
              .unique()
              .sort()

    file { '/etc/prometheus/targets/nodes.yaml':
        ensure  => present,
        mode    => '0444',
        content => template('prometheus/nodes.erb')
    }

    service { 'prometheus':
        ensure  => running,
        require => Package['prometheus'],
    }

    monitoring::services { 'Prometheus':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '9090',
        },
    }
}
