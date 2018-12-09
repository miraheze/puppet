# role: roundcubemail
class role::roundcubemail {
    motd::role { 'roundcubemail':
        description => 'hosts our webmail client',
    }

    include ::profile::roundcubemail::main

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
