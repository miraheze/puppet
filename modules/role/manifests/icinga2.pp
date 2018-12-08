# role: icinga2
class role::icinga2 {
    motd::role { 'icinga2':
        description => 'central monitoring server which runs icinga2',
    }

    include ::profile::icinga2::main

    if !defined(Exec['ufw-allow-tcp-from-any-to-any-port-80']) {
        ufw::allow { 'icinga2 http':
            proto => 'tcp',
            port  => '80',
        }
    }

    if !defined(Exec['ufw-allow-tcp-from-any-to-any-port-443']) {
        ufw::allow { 'icinga2 https':
            proto => 'tcp',
            port  => '443',
        }
    }
}
