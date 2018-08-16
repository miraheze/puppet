# role: prometheus
class role::prometheus {
    include ::prometheus

    ufw::allow { 'prometheus tcp':
        proto => 'tcp',
        port  => 9090,
        from  => '185.52.1.76',
    }

    motd::role { 'role::prometheus':
        description => 'central Prometheus server',
    }
}
