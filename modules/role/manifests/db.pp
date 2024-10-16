# class: role::db
class role::db (
    Optional[Array[String]] $daily_misc = lookup('role::db::daily_misc', {'default_value' => []}),
    Optional[Array[String]] $weekly_misc = lookup('role::db::weekly_misc', {'default_value' => []}),
    Optional[Array[String]] $fortnightly_misc = lookup('role::db::fornightly_misc', {'default_value' => []}),
    Optional[Array[String]] $monthly_misc = lookup('role::db::monthly_misc', {'default_value' => []}),
    Boolean $enable_bin_logs = lookup('role::db::enable_bin_logs', {'default_value' => true}),
    Boolean $enable_slow_log = lookup('role::db::enable_slow_log', {'default_value' => false}),
    Boolean $backup_sql = lookup('role::db::backup_sql', {'default_value' => true}),
    Boolean $enable_ssl = lookup('role::db::enable_ssl', {'default_value' => true}),
) {
    include mariadb::packages
    include prometheus::exporter::mariadb

    $mediawiki_password = lookup('passwords::db::mediawiki')
    $wikiadmin_password = lookup('passwords::db::wikiadmin')
    $matomo_password = lookup('passwords::db::matomo')
    $phorge_password = lookup('passwords::db::phorge')
    $exporter_password = lookup('passwords::db::exporter')
    $icinga_password = lookup('passwords::db::icinga')
    $icingaweb2_db_user_password = lookup('passwords::icingaweb2')
    $ido_db_user_password = lookup('passwords::icinga_ido')
    $reports_password = lookup('passwords::db::reports')

    ssl::wildcard { 'db wildcard': }

    file { '/etc/ssl/private':
        ensure => directory,
        owner  => 'root',
        group  => 'mysql',
        mode   => '0750',
    }

    class { 'mariadb::config':
        config          => 'mariadb/config/mw.cnf.erb',
        password        => lookup('passwords::db::root'),
        icinga_password => $icinga_password,
        enable_bin_logs => $enable_bin_logs,
        enable_ssl      => $enable_ssl,
        enable_slow_log => $enable_slow_log,
    }

    file { '/etc/mysql/wikitide/mediawiki-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/mediawiki-grants.sql.erb'),
    }

    file { '/etc/mysql/wikitide/matomo-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/matomo-grants.sql.erb'),
    }

    file { '/etc/mysql/wikitide/phorge-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/phorge-grants.sql.erb'),
    }

    file { '/etc/mysql/wikitide/icinga2-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/icinga2-grants.sql.erb'),
    }

    file { '/etc/mysql/wikitide/reports-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/reports-grants.sql.erb'),
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Db] or Class[Role::Mediawiki] or Class[Role::Mediawiki_task] or Class[Role::Mediawiki_beta] or Class[Role::Icinga2] or Class[Role::Phorge] or Class[Role::Matomo] or Class[Role::Reports]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'mariadb':
        proto   => 'tcp',
        port    => '3306',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    # Create a user to allow db transfers between servers
    users::user { 'dbcopy':
        ensure   => present,
        uid      => 3000,
        ssh_keys => [
            'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOL4FH2aRAwbSGP1HLmo1YzaXRci2YnkTGJvT2E6Ay0d dbcopy@db101'
        ],
    }

    # Backup provisioning
    file { '/srv/backups':
        ensure => directory,
    }

    system::role { 'db':
        description => 'MySQL database server',
    }

    file { '/var/log/db-backups':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    if $backup_sql {
        $monthday_1 = fqdn_rand(13, 'db-backups') + 1
        $monthday_15 = fqdn_rand(13, 'db-backups') + 15
        systemd::timer::job { 'db-backups':
            description       => 'Runs backup of all the wikis dbs',
            command           => '/usr/local/bin/wikitide-backup backup sql',
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => "*-*-${monthday_1},${monthday_15} 03:00:00",
            },
            logfile_basedir   => '/var/log/db-backups',
            logfile_name      => 'db-backups.log',
            syslog_identifier => 'db-backups',
            user              => 'root',
        }

        monitoring::nrpe { 'Backups SQL':
            command  => '/usr/lib/nagios/plugins/check_file_age -w 1382400 -c 1468800 -f /var/log/db-backups/db-backups.log',
            docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
            critical => true
        }
    }

    $daily_misc.each |String $db| {
        systemd::timer::job { "${db}-db-backups-daily":
            description       => "Runs backup of ${db} db daily",
            command           => "/usr/local/bin/wikitide-backup backup sql --database=${db}",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => '*-*-* 00:00:00',
            },
            logfile_basedir   => '/var/log/db-backups',
            logfile_name      => "${db}-db-backups-daily.log",
            syslog_identifier => "${db}-db-backups-daily",
            user              => 'root',
        }

        monitoring::nrpe { "Backups SQL ${db}":
            command  => "/usr/lib/nagios/plugins/check_file_age -w 129600 -c 172800 -f /var/log/db-backups/${db}-db-backups-daily/${db}-db-backups-daily.log",
            docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
            critical => true
        }
    }

    $weekly_misc.each |String $db| {
        systemd::timer::job { "${db}-db-backups-weekly":
            description       => "Runs backup of ${db} db weekly",
            command           => "/usr/local/bin/wikitide-backup backup sql --database=${db}",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => 'Sun *-*-* 05:00:00',
            },
            logfile_basedir   => '/var/log/db-backups',
            logfile_name      => "${db}-db-backups-weekly.log",
            syslog_identifier => "${db}-db-backups-weekly",
            user              => 'root',
        }

        monitoring::nrpe { "Backups SQL ${db}":
            command  => "/usr/lib/nagios/plugins/check_file_age -w 864000 -c 1209600 -f /var/log/db-backups/${db}-db-backups-weekly/${db}-db-backups-weekly.log",
            docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
            critical => true
        }
    }

    $fortnightly_misc.each |String $db| {
        systemd::timer::job { "${db}-db-backups-fortnightly":
            description       => "Runs backup of ${db} db fortnightly",
            command           => "/usr/local/bin/wikitide-backup backup sql --database=${db}",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => '*-*-1,15 05:00:00',
            },
            logfile_basedir   => '/var/log/db-backups',
            logfile_name      => "${db}-db-backups-fortnightly.log",
            syslog_identifier => "${db}-db-backups-fortnightly",
            user              => 'root',
        }

        monitoring::nrpe { "Backups SQL ${db}":
            command  => "/usr/lib/nagios/plugins/check_file_age -w 1555200 -c 1814400 -f /var/log/db-backups/${db}-db-backups-fortnightly/${db}-db-backups-fortnightly.log",
            docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
            critical => true
        }
    }

    $monthly_misc.each |String $db| {
        systemd::timer::job { "${db}-db-backups-monthly":
            description       => "Runs backup of ${db} db monthly",
            command           => "/usr/local/bin/wikitide-backup backup sql --database=${db}",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => '*-*-24 05:00:00',
            },
            logfile_basedir   => '/var/log/db-backups',
            logfile_name      => "${db}-db-backups-monthly.log",
            syslog_identifier => "${db}-db-backups-monthly",
            user              => 'root',
        }

        monitoring::nrpe { "Backups SQL ${db}":
            command  => "/usr/lib/nagios/plugins/check_file_age -w 3024000 -c 3456000 -f /var/log/db-backups/${db}-db-backups-monthly/${db}-db-backups-monthly.log",
            docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
            critical => true
        }
    }
}
