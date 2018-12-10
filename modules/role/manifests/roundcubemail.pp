# role: roundcubemail
class role::roundcubemail {
    motd::role { 'roundcubemail':
        description => 'hosts our webmail client',
    }

    include ::profile::roundcubemail::main

    ensure_resource_duplicate('ufw::allow', 'http', {'proto' => 'tcp', 'port' => '80'})

    ensure_resource_duplicate('ufw::allow', 'https', {'proto' => 'tcp', 'port' => '443'})
}
