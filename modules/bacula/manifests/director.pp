# Director: the bacula server
class bacula::director {
    package { ['bacula-director-sqlite3', 'bacula-server', 'bacula-client', 'python3-pexpect']:
        ensure => present,
    }

    service { 'bacula-director':
        ensure  => running,
        require => Package['bacula-server'],
    }

    service { 'bacula-fd':
        ensure  => running,
        require => Package['bacula-client'],
    }

    service { 'bacula-sd':
        ensure  => running,
        require => Package['bacula-server'],
    }

    $password = lookup('passwords::bacula::director')

    file { ['/bacula', '/bacula/backup', '/bacula/restore']:
        ensure => directory,
        owner  => 'bacula',
        require => Package['bacula-server'],
    }

    file { '/etc/bacula/bacula-dir.conf':
        ensure  => present,
        content => template('bacula/director/bacula-dir.conf'),
        require => Package['bacula-server'],
        notify  => Service['bacula-director'],
    }

    file { '/etc/bacula/bacula-fd.conf':
        ensure  => present,
        content => template('bacula/director/bacula-fd.conf'),
        require => Package['bacula-server'],
        notify  => Service['bacula-fd'],
    }

    file { '/etc/bacula/bacula-sd.conf':
        ensure  => present,
        content => template('bacula/director/bacula-sd.conf'),
        require => Package['bacula-server'],
        notify  => Service['bacula-sd'],
    }

    file { '/etc/bacula/bconsole.conf':
        ensure  => present,
        content => template('bacula/director/bconsole.conf'),
        require => Package['bacula-server'],
        notify  => Service['bacula-director'],
    }

    file { '/etc/bacula/tray-monitor.conf':
        ensure  => present,
        content => template('bacula/director/tray-monitor.conf'),
        require => Package['bacula-server'],
        notify  => Service['bacula-director'],
    }

    $firewall_rules = query_facts('Class[Bacula::Client]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')

    ferm::service { 'bacula 9101':
        proto  => 'tcp',
        port   => '9101',
        srange => "(${firewall_rules_str})",
    }

    ferm::service { 'bacula 9102':
        proto  => 'tcp',
        port   => '9102',
        srange => "(${firewall_rules_str})",
    }

    ferm::service { 'bacula 9103':
        proto  => 'tcp',
        port   => '9103',
        srange => "(${firewall_rules_str})",
    }

    file { '/usr/lib/nagios/plugins/check_bacula_backups':
        ensure  => present,
        source  => 'puppet:///modules/bacula/check_bacula_backups.py',
        mode    => '0555',
        require => Package['monitoring-plugins'],
    }

    # Bacula secret keys
    sudo::user { 'nrpe_sudo_checkbaculabackups':
        user       => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_bacula_backups' ],
    }

    monitoring::services { 'Bacula Daemon':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_bacula_daemon',
            nrpe_timeout => '60s',
        },
    }

    monitoring::services { 'Bacula Databases db11':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_bacula_databasesdb11',
            nrpe_timeout => '60s',
        },
    }

    monitoring::services { 'Bacula Databases db12':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_bacula_databasesdb12',
            nrpe_timeout => '60s',
        },
    }

    monitoring::services { 'Bacula Databases db13':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_bacula_databasesdb13',
            nrpe_timeout => '60s',
        },
    }

    monitoring::services { 'Bacula Static':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_bacula_static',
            nrpe_timeout => '60s',
        },
    }

    monitoring::services { 'Bacula Phabricator Static':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_bacula_phab',
            nrpe_timeout => '60s',
        },
    }

    monitoring::services { 'Bacula Private Git':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_bacula_private',
            nrpe_timeout => '60s',
        },
    }
}
