# UFW class
#
# Enabled on all servers, add exceptions in roles otherwise all traffic
# will be denied.
#
# To manage the firewall, use ufw::allow and ufw::logging
#
# ufw::allow { 'description':
#     port  => 22, # on port 22
#     from  => '10.0.0.0', # from 10.0.0.0 only
#     ip    => '10.0.0.1', # only to 10.0.0.1
#     proto => 'tcp', # tcp only
# }
#
# ufw::logging { 'no-log':
#     level => 'off',
# }
#
class ufw(
    $forward  = 'DROP',
) {

    package { 'ufw':
        ensure => present,
    }

    exec { 'ufw-default-deny':
        command => '/usr/sbin/ufw default deny',
        unless  => '/usr/sbin/ufw status verbose | grep -q "Default: deny (incoming), allow (outgoing)"',
    }

    exec { 'ufw-enable':
        command => '/usr/sbin/ufw --force enable',
        unless  => '/usr/sbin/ufw status | grep "Status: active"',
    }

    service { 'ufw':
        ensure    => running,
        enable    => true,
        hasstatus => true,
        subscribe => Package['ufw'],
    }

    ufw::logging { 'default': }
}
