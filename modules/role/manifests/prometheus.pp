# role: prometheus
class role::prometheus {
    include ::prometheus
    include prometheus::blackbox_exporter

    $firewall = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "prometheus ${value['ipaddress']}":
            proto => 'tcp',
            port  => 9090,
            from  => $value['ipaddress'],
        }

        ufw::allow { "prometheus ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 9090,
            from  => $value['ipaddress6'],
        }
    }

    motd::role { 'role::prometheus':
        description => 'central Prometheus server',
    }
}
