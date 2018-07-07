# role: grafana
class role::grafana {
    include ::grafana

    ufw::allow { 'grafana tcp':
        proto => 'tcp',
        port  => 2003,
    }

    ufw::allow { 'grafana2 tcp':
        proto => 'tcp',
        port  => 2004,
    }

    motd::role { 'role::grafana':
        description => 'central Grafana server',
    }
}
