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

    file { '/var/log/grafana-backup':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    $monthday_1 = fqdn_rand(13, 'grafana-backup') + 1
    $monthday_15 = fqdn_rand(13, 'grafana-backup') + 15
    systemd::timer::job { 'grafana-backup':
        description       => 'Runs backup of grafana',
        command           => '/usr/local/bin/wikitide-backup backup grafana',
        interval          => {
            'start'    => 'OnCalendar',
            'interval' => "*-*-${monthday_1},${monthday_15} 03:00:00",
        },
        logfile_basedir   => '/var/log/grafana-backup',
        logfile_name      => 'grafana-backup.log',
        syslog_identifier => 'grafana-backup',
        user              => 'root',
    }

    monitoring::nrpe { 'Backups Grafana':
        command  => '/usr/lib/nagios/plugins/check_file_age -w 1382400 -c 1468800 -f /var/log/grafana-backup.log',
        docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
        critical => true,
    }
}
