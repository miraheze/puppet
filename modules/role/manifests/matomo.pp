# role: matomo
class role::matomo {
    include ::matomo

    ensure_resource_duplicate('ufw::allow', 'http', {'proto' => 'tcp', 'port' => '80'})

    ensure_resource_duplicate('ufw::allow', 'https', {'proto' => 'tcp', 'port' => '443'})

    motd::role { 'role::matomo':
        description => 'central analytics server',
    }
}
