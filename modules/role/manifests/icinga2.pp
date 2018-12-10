# role: icinga2
class role::icinga2 {
    motd::role { 'icinga2':
        description => 'central monitoring server which runs icinga2',
    }

    include ::profile::icinga2::main

    ensure_resource_duplicate('ufw::allow', 'icinga2 http', {'proto' => 'tcp', 'port' => '80'})

    ensure_resource_duplicate('ufw::allow', 'icinga2 https', {'proto' => 'tcp', 'port' => '443'})
}
