# role: icinga2
class role::icinga2 {
    motd::role { 'icinga2':
        description => 'central monitoring server which runs icinga2',
    }

    include ::profile::icinga2::main
    
    ensure_resource_duplicate('ufw::allow', 'http', {'proto' => 'tcp', 'port' => '80'})

    ensure_resource_duplicate('ufw::allow', 'https', {'proto' => 'tcp', 'port' => '443'})
}
