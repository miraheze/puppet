# role: phabricator
class role::phabricator {
    include ::phabricator

    ensure_resource_duplicate('ufw::allow', 'http', {'proto' => 'tcp', 'port' => '80'})
    ensure_resource_duplicate('ufw::allow', 'https', {'proto' => 'tcp', 'port' => '443'})

    motd::role { 'role::phabricator':
        description => 'phabricator instance',
    }
}
