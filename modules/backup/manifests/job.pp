define backup::job (
    Variant[
        Systemd::Timer::Interval,
        Systemd::Timer::Datetime
    ] $interval,
    VMlib::Ensure $ensure = present,
    Optional[String] $backup_params = undef,
    Stdlib::Absolutepath $logfile_basedir = '/var/log',
) {
    stdlib::ensure_packages(['python3-fabric', 'python3-decorator'])

    $pca_password = lookup('private::passwords::pca')
    $use_gateway = lookup('backup::job::use_gateway', {'default_value' => true})

    if !defined(File['/usr/local/bin/wikitide-backup']) {
        file { '/usr/local/bin/wikitide-backup':
            mode    => '0555',
            content => template('backup/wikitide-backup.py.erb'),
        }
    }

    if !defined(File['/srv/backups']) {
        file { '/srv/backups':
            ensure => directory,
        }
    }

    if $backup_params {
        $params = $backup_params
    } else {
        $params = $title
    }

    systemd::timer::job { "${title}-backup":
        ensure              => $ensure,
        description         => "Runs backup of ${title}",
        command             => "/usr/local/bin/wikitide-backup backup ${params}",
        interval            => { 'start' => 'OnCalendar', 'interval' => $interval },
        logfile_basedir     => $logfile_basedir,
        logfile_name        => "${title}-backup.log",
        syslog_identifier   => "${title}-backup",
        user                => 'root',
        monitoring_docs_url => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
    }
}
