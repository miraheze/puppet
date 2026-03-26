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

    $subquery = @("PQL")
    resources { type = 'Class' and title = 'Prometheus' }
    | PQL
    $firewall_rules = vmlib::generate_firewall_ip($subquery)
    ferm::service { 'prometheus nginx':
        proto  => 'tcp',
        port   => '9113',
        srange => "(${firewall_rules})",
    }
}
