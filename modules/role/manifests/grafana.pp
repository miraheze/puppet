# role: grafana
class role::grafana {
    motd::role { 'role::grafana':
        description => 'central Grafana server',
    }

    include ::grafana

    ufw::allow { 'grafana tcp':
        proto => 'tcp',
        port  => 2003,
    }

    ufw::allow { 'grafana2 tcp':
        proto => 'tcp',
        port  => 2004,
    }

    ensure_resource_duplicate('ufw::allow', 'grafana http', {'proto' => 'tcp', 'port' => '80'})

    ensure_resource_duplicate('ufw::allow', 'grafana https', {'proto' => 'tcp', 'port' => '443'})
}
