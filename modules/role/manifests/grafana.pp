# role: grafana
class role::grafana {
    include ::grafana

    if defined(Ufw::Allow['icinga http']) {
        ufw::allow { 'icinga access':
            proto => 'tcp',
            port  => '80',
        }
    }

    if defined(Ufw::Allow['icinga https']) {
        ufw::allow { 'icinga access':
            proto => 'tcp',
            port  => '443',
        }
    }

    ufw::allow { 'grafana tcp':
        proto => 'tcp',
        port  => 2003,
    }

    ufw::allow { 'grafana2 tcp':
        proto => 'tcp',
        port  => 2004,
    }

    motd::role { 'role::grafana':
        description => 'central Grafana server',
    }
}
