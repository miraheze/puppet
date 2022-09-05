# = Class: prometheus::exporter::nginx
#

class prometheus::exporter::nginx {

    file { '/usr/local/bin/nginx-prometheus-exporter':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/nginx/nginx-prometheus-exporter',
        notify => Service['nginx-prometheus-exporter'],
    }

    systemd::service { 'nginx-prometheus-exporter':
        ensure  => present,
        content => systemd_template('nginx-prometheus-exporter'),
        restart => true,
        require => [
            File['/usr/local/bin/nginx-prometheus-exporter'],
        ],
    }

    $firewall_rules = join(
        query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

    ferm::service { 'prometheus nginx':
        proto  => 'tcp',
        port   => '9113',
        srange => "(${firewall_rules})",
    }
}
