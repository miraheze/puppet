# class: prometheus
class prometheus (
    Hash $global_extra = {},
    Array $scrape_extra = [],
    Integer $port = 9100,
    String $public_proxy_url = lookup('prometheus::public_proxy_url', {'default_value' => 'http://bastion.fsslc.wtnet:8080'}),
) {

    stdlib::ensure_packages('prometheus')

    file { '/etc/prometheus/targets':
        ensure => directory
    }

    file { '/etc/prometheus/targets/public':
        ensure  => directory,
        require => File['/etc/prometheus/targets'],
    }

    $global_default = {
        'scrape_interval' => '60s',
    }
    $global_config = $global_default + $global_extra

    $scrape_default = [
        {
            'job_name' => 'prometheus',
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
    $base_jobs = concat($scrape_default, $scrape_extra)

    # Only these jobs run on hosts without a private IP.
    $public_job_names = ['node', 'nginx']
    $public_jobs = $base_jobs.filter |$job| { $job['job_name'] in $public_job_names }.map |$job| {
        $relabel = $job['relabel_configs'] ? {
            Array   => $job['relabel_configs'],
            default => [],
        }
        $public_job = $job + {
            'job_name'        => "${job['job_name']}_public",
            'proxy_url'       => $public_proxy_url,
            'relabel_configs' => $relabel + [{ 'target_label' => 'job', 'replacement' => $job['job_name'] }],
            'file_sd_configs' => $job['file_sd_configs'].map |$sd| {
                $sd_public = $sd + {
                    'files' => $sd['files'].map |$file| {
                        regsubst(regsubst($file, '^targets/', 'targets/public/'), '^/etc/prometheus/targets/', '/etc/prometheus/targets/public/')
                    },
                }
                $sd_public
            },
        }
        $public_job
    }

    $scrape_config = concat($base_jobs, $public_jobs)

    $common_config = {
        'global' => $global_config,
        'rule_files' => [],
        'scrape_configs' => $scrape_config
    }

    file { '/etc/prometheus/prometheus.yml':
        content => stdlib::to_yaml($common_config),
        notify  => Exec['prometheus-reload']
    }

    exec { 'prometheus-reload':
        command     => '/bin/systemctl reload prometheus',
        refreshonly => true,
    }

    $pdb_query = @("PQL")
        nodes[certname] {
            resources {type = "Class" and title = "Base"}
            order by certname
        }
    | PQL
    $servers = puppetdb_query($pdb_query).map |$x| { $x['certname'] }
              .flatten()
              .unique()
              .sort()

    $node_groups = vmlib::scrape_groups($servers, $port)

    file { '/etc/prometheus/targets/nodes.yaml':
        ensure  => present,
        mode    => '0444',
        content => epp('prometheus/nodes.epp', { 'groups' => $node_groups['internal'] }),
    }

    file { '/etc/prometheus/targets/public/nodes.yaml':
        ensure  => present,
        mode    => '0444',
        content => epp('prometheus/nodes.epp', { 'groups' => $node_groups['public'] }),
        require => File['/etc/prometheus/targets/public'],
    }

    systemd::service { 'prometheus':
        ensure         => present,
        restart        => true,
        content        => systemd_template('prometheus'),
        service_params => {
            hasrestart => true,
        },
    }

    logrotate::conf { 'prometheus':
        ensure => present,
        source => 'puppet:///modules/prometheus/prometheus.logrotate.conf',
    }

    rsyslog::conf { 'prometheus':
        source   => 'puppet:///modules/prometheus/prometheus.rsyslog.conf',
        priority => 40,
    }

    class { 'prometheus::pushgateway':
        ensure      => present,
        listen_port => 9091,
    }

    monitoring::services { 'Prometheus':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '9090',
        },
    }
}
