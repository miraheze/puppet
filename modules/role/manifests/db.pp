# class: role::db
class role::db (
    Optional[Array[String]] $weekly_misc = lookup('role::db::weekly_misc', {'default_value' => []}),
    Optional[Array[String]] $fortnightly_misc = lookup('role::db::fornightly_misc', {'default_value' => []}),
    Optional[Array[String]] $monthly_misc = lookup('role::db::monthly_misc', {'default_value' => []})
) {
    include mariadb::packages
    include prometheus::exporter::mariadb

    $mediawiki_password = lookup('passwords::db::mediawiki')
    $wikiadmin_password = lookup('passwords::db::wikiadmin')
    $piwik_password = lookup('passwords::db::piwik')
    $phabricator_password = lookup('passwords::db::phabricator')
    $grafana_password = lookup('passwords::db::grafana')
    $exporter_password = lookup('passwords::db::exporter')
    $icinga_password = lookup('passwords::db::icinga')
    $roundcubemail_password = lookup('passwords::roundcubemail')
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
    }

    file { '/etc/mysql/miraheze/grafana-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/grafana-grants.sql.erb'),
    }

    file { '/etc/mysql/miraheze/mediawiki-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/mediawiki-grants.sql.erb'),
    }

    file { '/etc/mysql/miraheze/piwik-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/piwik-grants.sql.erb'),
    }

    file { '/etc/mysql/miraheze/phabricator-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/phabricator-grants.sql.erb'),
    }

    file { '/etc/mysql/miraheze/roundcubemail-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/roundcubemail-grants.sql.erb'),
    }

    file { '/etc/mysql/miraheze/icinga2-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/icinga2-grants.sql.erb'),
    }

    file { '/etc/mysql/miraheze/reports-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/reports-grants.sql.erb'),
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Db] or Class[Role::Mediawiki] or Class[Role::Icinga2] or Class[Role::Roundcubemail] or Class[Role::Phabricator] or Class[Role::Matomo] or Class[Role::Reports]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
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

    cron { 'DB_backups':
        ensure  => absent,
        command => "/usr/bin/mydumper -N -W -k --less-locking -m -v 3 -t 1 -c -x '^(?!((mysql|performance_schema|information_schema).+|[0-9a-z]+wiki.(objectcache|querycache|querycachetwo|recentchanges|searchindex)))' --trx-consistency-only -o '/srv/backups/dbs' -L '/srv/backups/recent.log'",
        user    => 'root',
        minute  => '0',
        hour    => fqdn_rand(23, 'mydumper'),
    }

    motd::role { 'role::db':
        description => 'general database server',
    }

    cron { 'backups-sql':
        ensure   => present,
        command  => '/usr/local/bin/miraheze-backup backup sql > /var/log/sql-backup.log 2>&1',
        user     => 'root',
        minute   => '0',
        hour     => '3',
        monthday => [fqdn_rand(13, 'db-backups') + 1, fqdn_rand(13, 'db-backups') + 15],
    }

    monitoring::nrpe { 'Backups SQL':
        command  => '/usr/lib/nagios/plugins/check_file_age -w 864000 -c 1209600 -f /var/log/sql-backup.log',
        docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
        critical => true
    }

    $weekly_misc.each |String $db| {
        cron { "backups-${db}":
            ensure  => present,
            command => "/usr/local/bin/miraheze-backup backup sql --database=${db} > /var/log/sql-${db}-backup-weekly.log 2>&1",
            user    => 'root',
            minute  => '0',
            hour    => '5',
            weekday => '0',
        }

        monitoring::nrpe { "Backups SQL ${db}":
            command  => "/usr/lib/nagios/plugins/check_file_age -w 864000 -c 1209600 -f /var/log/sql-${db}-backup-weekly.log",
            docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
            critical => true
        }
    }

    $fortnightly_misc.each |String $db| {
        cron { "backups-${db}":
            ensure   => present,
            command  => "/usr/local/bin/miraheze-backup backup sql --database=${db} > /var/log/sql-${db}-backup-fortnightly.log 2>&1",
            user     => 'root',
            minute   => '0',
            hour     => '5',
            monthday => ['1', '15'],
        }

        monitoring::nrpe { "Backups SQL ${db}":
            command  => "/usr/lib/nagios/plugins/check_file_age -w 1555200 -c 1814400 -f /var/log/sql-${db}-backup-fortnightly.log",
            docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
            critical => true
        }
    }

    $monthly_misc.each |String $db| {
        cron { "backups-${db}":
            ensure   => present,
            command  => "/usr/local/bin/miraheze-backup backup sql --database=${db} > /var/log/sql-${db}-backup-monthly.log 2>&1",
            user     => 'root',
            minute   => '0',
            hour     => '5',
            monthday => ['24'],
        }

        monitoring::nrpe { "Backups SQL ${db}":
            command  => "/usr/lib/nagios/plugins/check_file_age -w 3024000 -c 3456000 -f /var/log/sql-${db}-backup-monthly.log",
            docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
            critical => true
        }
    }
}
