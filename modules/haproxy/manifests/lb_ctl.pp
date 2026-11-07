# === Class haproxy::lb_ctl
#
# lb-ctl shows the load balancer pools of this host and depools, drains or
# repools one server in them.
class haproxy::lb_ctl {
    file { '/usr/local/sbin/lb-ctl':
        ensure => present,
        source => 'puppet:///modules/haproxy/lb-ctl.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }
}
