# === Class haproxy::lb_monitoring
#
# Icinga check for pool servers that are down or depooled.
class haproxy::lb_monitoring {
    file { '/usr/lib/nagios/plugins/check_haproxy_backends':
        ensure => present,
        source => 'puppet:///modules/haproxy/icinga/check_haproxy_backends.py',
        mode   => '0755',
    }

    # The admin socket is only readable by root
    sudo::user { 'nrpe_sudo_checkhaproxybackends':
        user       => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_haproxy_backends' ],
    }

    monitoring::nrpe { 'HAProxy Backends':
        command => '/usr/bin/sudo /usr/lib/nagios/plugins/check_haproxy_backends',
    }
}
