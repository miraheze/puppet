# role: grafana
class role::grafana {
    motd::role { 'role::grafana':
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

    cron { 'grafana-backup':
        ensure   => present,
        command  => '/usr/local/bin/miraheze-backup backup grafana > /var/log/grafana-backup.log 2>&1',
        user     => 'root',
        minute   => '0',
        hour     => '3',
        monthday => [fqdn_rand(13, 'grafana-backup') + 1, fqdn_rand(13, 'grafana-backup') + 15],
    }

    monitoring::nrpe { 'Backups Grafana':
        command  => '/usr/lib/nagios/plugins/check_file_age -w 864000 -c 1209600 -f /var/log/grafana-backup.log',
        docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
        critical => true
    }
}
