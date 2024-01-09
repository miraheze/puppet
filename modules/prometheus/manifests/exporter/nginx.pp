# = Class: prometheus::exporter::nginx
#

class prometheus::exporter::nginx {
    stdlib::ensure_packages('prometheus-nginx-exporter')

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
        query_facts('Class[Prometheus]', ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
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
