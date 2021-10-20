# role: grafana
class role::grafana {
    motd::role { 'role::grafana':
        description => 'central Grafana server',
    }

    include ::grafana

    if !defined(Ferm::Service['http']) {
        ferm::service { 'http':
            proto   => 'tcp',
            port    => '80',
            notrack => true,
        }
    }

    if !defined(Ferm::Service['https']) {
        ferm::service { 'https':
            proto   => 'tcp',
            port    => '443',
            notrack => true,
        }
    }
}
