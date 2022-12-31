# = Class: prometheus::exporter::nginx
#

class prometheus::exporter::nginx {

    systemd::service { 'nginx-prometheus-exporter':
        ensure  => absent,
        content => systemd_template('nginx-prometheus-exporter'),
    }

    ensure_packages('prometheus-nginx-exporter')

    file { '/etc/default/prometheus-nginx-exporter':
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => "ARGS='-nginx.scrape-uri=http://localhost:8090/server-status'\n",
        require => Package['prometheus-nginx-exporter'],
    }

    service { 'prometheus-nginx-exporter':
        ensure    => running,
        subscribe => File['/etc/default/prometheus-nginx-exporter'],
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
