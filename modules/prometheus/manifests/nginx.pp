# = Class: prometheus::nginx
#

class prometheus::nginx {

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

    $firewall = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "prometheus 9113 ipv4 ${value['ipaddress']}":
            proto => 'tcp',
            port  => 9113,
            from  => $value['ipaddress'],
        }

        ufw::allow { "prometheus 9113 ipv6 ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 9113,
            from  => $value['ipaddress6'],
        }
    }
}
