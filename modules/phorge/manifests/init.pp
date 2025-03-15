# class: phorge
class phorge (
  Integer $request_timeout = lookup('phorge::php::request_timeout', {'default_value' => 60}),
) {
    stdlib::ensure_packages(['mariadb-client', 'python3-pygments', 'subversion'])

    $fpm_config = {
        'include_path'                    => '".:/usr/share/php"',
        'error_log'                       => 'syslog',
        'pcre.backtrack_limit'            => 5000000,
        'date.timezone'                   => 'UTC',
        'display_errors'                  => 0,
        'error_reporting'                 => 'E_ALL & ~E_STRICT',
        'mysql'                           => { 'connect_timeout' => 3 },
        'default_socket_timeout'          => 60,
        'enable_dl'                       => 0,
        'opcache' => {
                'enable' => 1,
                'interned_strings_buffer' => 40,
                'memory_consumption' => 256,
                'max_accelerated_files' => 20000,
                'max_wasted_percentage' => 10,
                'validate_timestamps' => 1,
                'revalidate_freq' => 10,
        },
        'max_execution_time' => 60,
        'post_max_size' => '10M',
        'track_errors' => 'Off',
        'upload_max_filesize' => '10M',
    }

    $core_extensions =  [
        'curl',
        'gd',
        'gmp',
        'intl',
        'mbstring',
        'ldap',
        'zip',
    ]

    $php_version = lookup('php::php_version', {'default_value' => '8.2'})

    # Install the runtime
    class { '::php':
        ensure         => present,
        version        => $php_version,
        sapis          => ['cli', 'fpm'],
        config_by_sapi => {
            'fpm' => $fpm_config,
        },
    }

    $core_extensions.each |$extension| {
        php::extension { $extension:
            package_name => "php${php_version}-${extension}",
            sapis        => ['cli', 'fpm'],
        }
    }

    class { '::php::fpm':
        ensure => present,
        config => {
            'emergency_restart_interval'  => '60s',
            'emergency_restart_threshold' => $facts['processors']['count'],
            'process.priority'            => -19,
        },
    }

    # Extensions that require configuration.
    php::extension {
        default:
            sapis => ['cli', 'fpm'];
        'apcu':
            ;
        'mailparse':
            priority => 21;
        'mysqlnd':
            package_name => '',
            priority     => 10;
        'xml':
            package_name => "php${php_version}-xml",
            priority     => 15;
        'mysqli':
            package_name => "php${php_version}-mysql";
    }

    $fpm_workers_multiplier = lookup('php::fpm::fpm_workers_multiplier', {'default_value' => 1.5})
    $fpm_min_child = lookup('php::fpm::fpm_min_child', {'default_value' => 4})

    $num_workers = max(floor($facts['processors']['count'] * $fpm_workers_multiplier), $fpm_min_child)
    php::fpm::pool { 'www':
        config => {
            'pm'                        => 'static',
            'pm.max_children'           => $num_workers,
            'request_terminate_timeout' => $request_timeout,
            'request_slowlog_timeout'   => 15,
        }
    }

    $password = lookup('passwords::irc::mirahezebots')

    nginx::site { 'phorge-static.wikitide.net':
        ensure  => present,
        source  => 'puppet:///modules/phorge/phorge-static.wikitide.net.conf',
        monitor => false,
    }

    nginx::site { 'issue-tracker.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/phorge/issue-tracker.miraheze.org.conf',
        monitor => false,
    }

    ssl::wildcard { 'phorge wildcard': }
    ssl::client_cert_cas { 'phorge client_cert_cas': }

    file { '/srv/phorge':
        ensure => directory,
    }

    file { '/srv/phorge/libext':
        ensure  => directory,
        require => File['/srv/phorge']
    }

    git::clone { 'arcanist':
        ensure    => present,
        directory => '/srv/phorge/arcanist',
        origin    => 'https://github.com/phorgeit/arcanist',
        require   => File['/srv/phorge'],
    }

    git::clone { 'phorge':
        ensure    => present,
        directory => '/srv/phorge/phorge',
        origin    => 'https://github.com/phorgeit/phorge',
        require   => File['/srv/phorge'],
    }

    git::clone { 'phorge-extensions':
        ensure    => latest,
        directory => '/srv/phorge/libext/phorge-extensions',
        origin    => 'https://github.com/miraheze/phorge-extensions',
        require   => File['/srv/phorge/libext'],
    }

    file { '/srv/phorge/repos':
        ensure => directory,
        mode   => '0755',
        owner  => 'www-data',
        group  => 'www-data',
    }

    file { '/srv/phorge/images':
        ensure => directory,
        mode   => '0755',
        owner  => 'www-data',
        group  => 'www-data',
    }

    $module_path = get_module_path($module_name)
    $phorge_yaml = loadyaml("${module_path}/data/config.yaml")
    $phorge_private = {
        'mysql.pass' => lookup('passwords::db::phorge'),
    }

    $phorge_setting = {
        # smtp
        'cluster.mailers'      => [
            {
                'key'          => 'miraheze-smtp',
                'type'         => 'smtp',
                'options'      => {
                    'host'     => 'smtp-relay.gmail.com',
                    'port'     => 465,
                    'protocol' => 'ssl',
                },
            },
        ],
    }

    $phorge_settings = $phorge_yaml + $phorge_private + $phorge_setting

    file { '/srv/phorge/phorge/conf/local/local.json':
        ensure  => present,
        content => stdlib::to_json_pretty($phorge_settings),
        notify  => Service['phd'],
        require => Git::Clone['phorge'],
    }

    systemd::service { 'phd':
        ensure  => present,
        content => systemd_template('phd'),
        restart => true,
        require => File['/srv/phorge/phorge/conf/local/local.json'],
    }

    if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens19']['ip']
    } elsif ( $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address = $facts['networking']['ip6']
    }

    monitoring::services { 'phorge-static.wikitide.net HTTPS':
        check_command => 'check_http',
        vars          => {
            address6    => $address,
            http_expect => 'HTTP/1.1 200',
            http_ssl    => true,
            http_vhost  => 'phorge-static.wikitide.net',
            http_uri    => 'https://phorge-static.wikitide.net/file/data/b6eckvcmsmmjwe6gb2as/PHID-FILE-c6u44mun2axi3qq63u5t/ManageWiki-GH.png'
        },
    }

    monitoring::services { 'issue-tracker.miraheze.org HTTPS':
        check_command => 'check_http',
        vars          => {
            address6   => $address,
            http_ssl   => true,
            http_vhost => 'issue-tracker.miraheze.org',
        },
    }

    monitoring::nrpe { 'phd':
        command => '/usr/lib/nagios/plugins/check_procs -a phd -c 1:'
    }

    # Backup provisioning
    file { '/srv/backups':
        ensure => directory,
    }

    file { '/var/log/phorge-backup':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    systemd::timer::job { 'phorge-backup':
        description       => 'Runs backup of phorge',
        command           => '/usr/local/bin/wikitide-backup backup phorge',
        interval          => {
            'start'    => 'OnCalendar',
            'interval' => '*-*-1,15 01:00:00',
        },
        logfile_basedir   => '/var/log/phorge-backup',
        logfile_name      => 'phorge-backup.log',
        syslog_identifier => 'phorge-backup',
        user              => 'root',
    }

    monitoring::nrpe { 'Backups Phorge Static':
        command  => '/usr/lib/nagios/plugins/check_file_age -w 1555200 -c 1814400 -f /var/log/phorge-backup/phorge-backup/phorge-backup.log',
        docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
        critical => true
    }
}
