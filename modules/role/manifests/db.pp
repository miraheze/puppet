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
    Boolean $is_beta_db = lookup('role::db::is_beta_db', {'default_value' => false}),
) {
    include mariadb::packages
    include prometheus::exporter::mariadb

    if ( $is_beta_db ) {
        $mediawiki_password = lookup('passwords::db::mediawiki_beta')
        $wikiadmin_password = lookup('passwords::db::wikiadmin_beta')
    } else {
        $mediawiki_password = lookup('passwords::db::mediawiki')
        $wikiadmin_password = lookup('passwords::db::wikiadmin')
    }
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

    if ( $is_beta_db ) {
        $query_classes = 'Class[Role::Db] or Class[Role::Mediawiki] or Class[Role::Mediawiki_task] or Class[Role::Mediawiki_beta] or Class[Role::Icinga2] or Class[Role::Phorge] or Class[Role::Matomo] or Class[Role::Reports]'
    } else {
        $query_classes = 'Class[Role::Db] or Class[Role::Mediawiki] or Class[Role::Mediawiki_task] or Class[Role::Icinga2] or Class[Role::Phorge] or Class[Role::Matomo] or Class[Role::Reports]'
    }

    $firewall_rules_str = join(
        query_facts($query_classes, ['networking'])
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
            'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDHPGyXQ6O2Cy+LxP3BwtbzaUufVTihefglsUoWkBiIl dbcopy@wikitide.net'
        ],
    }

    file { '/home/dbcopy/.ssh':
        ensure => 'directory',
        owner  => 'dbcopy',
        group  => 'dbcopy',
        mode   => '0700',
    }

    file { '/home/dbcopy/.ssh/id_ed25519':
        ensure  => 'present',
        source  => 'puppet:///private/mariadb/dbcopy-ssh-key',
        owner   => 'dbcopy',
        group   => 'dbcopy',
        mode    => '0400',
        require => File['/home/dbcopy/.ssh'],
    }

    # Backups
    if $backup_sql {
        $monthday_1 = fqdn_rand(13, 'sql-backups') + 1
        $monthday_15 = fqdn_rand(13, 'sql-backups') + 15
        backup::job { 'sql':
            ensure          => present,
            interval        => "*-*-${monthday_1},${monthday_15} 03:00:00",
            logfile_basedir => '/var/log/sql-backups',
        }
    }

    $daily_misc.each |String $db| {
        backup::job { 'sql-daily':
            ensure          => present,
            interval        => '*-*-* 00:00:00',
            backup_params   => "sql --database=${db}",
            logfile_basedir => '/var/log/sql-backups',
        }
    }

    $weekly_misc.each |String $db| {
        backup::job { 'sql-weekly':
            ensure          => present,
            interval        => 'Sun *-*-* 05:00:00',
            backup_params   => "sql --database=${db}",
            logfile_basedir => '/var/log/sql-backups',
        }
    }

    $fortnightly_misc.each |String $db| {
        backup::job { 'sql-fortnightly':
            ensure          => present,
            interval        => '*-*-1,15 05:00:00',
            backup_params   => "sql --database=${db}",
            logfile_basedir => '/var/log/sql-backups',
        }
    }

    $monthly_misc.each |String $db| {
        backup::job { 'sql-monthly':
            ensure          => present,
            interval        => '*-*-24 05:00:00',
            backup_params   => "sql --database=${db}",
            logfile_basedir => '/var/log/sql-backups',
        }
    }

    system::role { 'db':
        description => 'MySQL database server',
    }
}
