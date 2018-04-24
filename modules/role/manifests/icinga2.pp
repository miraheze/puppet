# role: icinga
class role::icinga2 {
    include ::icinga2::custom::conf

    #ufw::allow { 'icinga2 http':
    #    proto => 'tcp',
    #    port  => '80',
    #}

    #ufw::allow { 'icinga2 https':
    #    proto => 'tcp',
    #    port  => '443',
    #}

    motd::role { 'role::icinga2':
        description => 'central monitoring server',
    }
}
