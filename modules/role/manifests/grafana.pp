# role: grafana
class role::grafana {
    motd::role { 'role::grafana':
        description => 'central Grafana server',
    }

    include ::grafana

    ensure_resource_duplicate('ufw::allow', 'http', {'proto' => 'tcp', 'port' => '80'})

    ensure_resource_duplicate('ufw::allow', 'https', {'proto' => 'tcp', 'port' => '443'})
}
