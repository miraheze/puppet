# role: grafana
class role::grafana {
    system::role { 'grafana':
        description => 'Grafana server',
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

    if !defined(Ferm::Service['https-quic']) {
        ferm::service { 'https-quic':
            proto   => 'udp',
            port    => '443',
            notrack => true,
        }
    }

    # Backups
    $monthday_1 = fqdn_rand(13, 'grafana-backup') + 1
    $monthday_15 = fqdn_rand(13, 'grafana-backup') + 15
    backup::job { 'grafana':
        ensure   => present,
        interval => "*-*-${monthday_1},${monthday_15} 03:00:00",
    }
}
