# class: phabricator
class phabricator (
  Integer $request_timeout = lookup('phabricator::php::request_timeout', {'default_value' => 60}),
) {
    stdlib::ensure_packages(['python3-pygments', 'subversion'])

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
            sapis        => ['cli', 'fpm'];
        'apcu':
            ;
        'mailparse':
            priority     => 21;
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

    nginx::site { 'phab.miraheze.wiki':
        ensure  => present,
        source  => 'puppet:///modules/phabricator/phab.miraheze.wiki.conf',
        monitor => false,
    }

    nginx::site { 'phabricator.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/phabricator/phabricator.miraheze.org.conf',
        monitor => false,
    }

    ssl::wildcard { 'phabricator wildcard': }
    ssl::cert { 'miraheze.wiki': }

    file { '/srv/phab':
        ensure => directory,
    }

    file { '/srv/phab/libext':
        ensure  => directory,
        require => File['/srv/phab']
    }

    git::clone { 'arcanist':
        ensure    => present,
        directory => '/srv/phab/arcanist',
        origin    => 'https://github.com/phorgeit/arcanist.git',
        require   => File['/srv/phab'],
    }

    git::clone { 'phorge':
        ensure    => present,
        directory => '/srv/phab/phorge',
        origin    => 'https://github.com/phorgeit/phorge.git',
        require   => File['/srv/phab'],
    }

    git::clone { 'phabricator-extensions':
        ensure    => latest,
        directory => '/srv/phab/libext/phab-extensions',
        origin    => 'https://github.com/miraheze/phabricator-extensions.git',
        require   => File['/srv/phab/libext'],
    }

    file { '/srv/phab/repos':
        ensure => directory,
        mode   => '0755',
        owner  => 'www-data',
        group  => 'www-data',
    }

    file { '/srv/phab/images':
        ensure => directory,
        mode   => '0755',
        owner  => 'www-data',
        group  => 'www-data',
    }

    $module_path = get_module_path($module_name)
    $phab_yaml = loadyaml("${module_path}/data/config.yaml")
    $phab_private = {
        'mysql.pass' => lookup('passwords::db::phabricator'),
    }

    $phab_setting = {
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

    $phab_settings = $phab_yaml + $phab_private + $phab_setting

    file { '/srv/phab/phorge/conf/local/local.json':
        ensure  => present,
        content => stdlib::to_json_pretty($phab_settings),
        notify  => Service['phd'],
        require => Git::Clone['phorge'],
    }

    systemd::service { 'phd':
        ensure  => present,
        content => systemd_template('phd'),
        restart => true,
        require => File['/srv/phab/phorge/conf/local/local.json'],
    }

    if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens19']['ip']
    } elsif ( $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address = $facts['networking']['ip6']
    }

    monitoring::services { 'phab.miraheze.wiki HTTPS':
        check_command => 'check_http',
        vars          => {
            address6    => $address,
            http_expect => 'HTTP/1.1 200',
            http_ssl    => true,
            http_vhost  => 'phab.miraheze.wiki',
            http_uri    => 'https://phab.miraheze.wiki/file/data/b6eckvcmsmmjwe6gb2as/PHID-FILE-c6u44mun2axi3qq63u5t/ManageWiki-GH.png'
        },
    }

    monitoring::services { 'phabricator.miraheze.org HTTPS':
        check_command => 'check_http',
        vars          => {
            address6    => $address,
            http_ssl   => true,
            http_vhost => 'phabricator.miraheze.org',
        },
    }

    monitoring::nrpe { 'phd':
        command => '/usr/lib/nagios/plugins/check_procs -a phd -c 1:'
    }

    cron { 'backups-phabricator':
        ensure   => present,
        command  => '/usr/local/bin/miraheze-backup backup phabricator > /var/log/phabricator-backup.log 2>&1',
        user     => 'root',
        minute   => '0',
        hour     => '1',
        monthday => ['1', '15'],
    }

    monitoring::nrpe { 'Backups Phabricator Static':
        command  => '/usr/lib/nagios/plugins/check_file_age -w 1555200 -c 1814400 -f /var/log/phabricator-backup.log',
        docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
        critical => true
    }
}
