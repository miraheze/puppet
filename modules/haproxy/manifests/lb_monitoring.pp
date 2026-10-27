# === Class haproxy::lb_monitoring
#
# Icinga check for pool servers that are down or out of rotation.
class haproxy::lb_monitoring {
    file { '/usr/lib/nagios/plugins/check_haproxy_servers':
        ensure => present,
        source => 'puppet:///modules/haproxy/icinga/check_haproxy_servers.py',
        mode   => '0755',
    }

    # The admin socket is only readable by root
    sudo::user { 'nrpe_sudo_checkhaproxyservers':
        user       => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_haproxy_servers' ],
    }

    monitoring::nrpe { 'HAProxy Servers':
        command => '/usr/bin/sudo /usr/lib/nagios/plugins/check_haproxy_servers',
    }

    # TODO: remove once puppet runs
    file { '/usr/lib/nagios/plugins/check_haproxy_backends':
        ensure => absent,
    }

    sudo::user { 'nrpe_sudo_checkhaproxybackends':
        ensure     => absent,
        user       => 'nagios',
        privileges => [],
    }

    monitoring::nrpe { 'HAProxy Backends':
        ensure  => absent,
        command => '/bin/true',
    }
}
