# class: matomo
class matomo (
    String $ldap_password  = lookup('passwords::matomo::ldap_password'),
    String $matomo_db_host = 'db182.wikitide.net',
) {
    stdlib::ensure_packages('composer')

    git::clone { 'matomo':
        directory          => '/srv/matomo',
        origin             => 'https://github.com/matomo-org/matomo',
        branch             => '5.0.1', # Current stable
        recurse_submodules => true,
        owner              => 'www-data',
        group              => 'www-data',
    }

    file { '/srv/matomo/misc/GeoLite2-Country.mmdb':
        ensure  => present,
        source  => 'puppet:///private/geoip/GeoLite2-Country.mmdb',
        mode    => '0444',
        require => Git::Clone['matomo'],
    }

    exec { 'matomo_composer':
        command     => 'composer install --no-dev',
        creates     => '/srv/matomo/vendor',
        cwd         => '/srv/matomo',
        path        => '/usr/bin',
        environment => 'HOME=/srv/matomo',
        user        => 'www-data',
        require     => Git::Clone['matomo'],
    }

    $config_cli = {
        'include_path'           => '".:/usr/share/php"',
        'error_log'              => 'syslog',
        'pcre.backtrack_limit'   => 5000000,
        'date.timezone'          => 'UTC',
        'display_errors'         => 'stderr',
        'memory_limit'           => lookup('php::cli::memory_limit', {'default_value' => '1G'}),
        'error_reporting'        => 'E_ALL & ~E_STRICT',
        'mysql'                  => { 'connect_timeout' => 3 },
        'default_socket_timeout' => 60,
    }

    $config_fpm = {
        'memory_limit' => lookup('php::fpm::memory_limit', {'default_value' => '1G'}),
        'display_errors' => 0,
        'session.upload_progress.enabled' => 0,
        'enable_dl' => 0,
        'opcache' => {
            'enable' => 1,
            'interned_strings_buffer' => 30,
            'memory_consumption' => 112,
            'max_accelerated_files' => 20000,
            'max_wasted_percentage' => 10,
            'validate_timestamps' => 1,
            'revalidate_freq' => 10,
        },
        'max_execution_time' => 60,
        'post_max_size' => '60M',
        'track_errors' => 'Off',
        'upload_max_filesize' => '100M',
    }

    $php_version = lookup('php::php_version', {'default_value' => '8.2'})

    # Install the runtime
    class { '::php':
        ensure         => present,
        version        => $php_version,
        sapis          => ['cli', 'fpm'],
        config_by_sapi => {
            'cli' => $config_cli,
            'fpm' => $config_cli + $config_fpm,
        },
    }

    $core_extensions =  [
        'curl',
        'gd',
        'gmp',
        'intl',
        'mbstring',
        'ldap',
    ]

    $core_extensions.each |$extension| {
        php::extension { $extension:
            package_name => "php${php_version}-${extension}",
            sapis        => ['cli', 'fpm'],
        }
    }

    # Requires igbinary to be installed
    php::extension { 'redis':
        ensure => present
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
        'xml':
            package_name => "php${php_version}-xml",
            priority     => 15;
        'igbinary':
            config   => {
                'extension'                => 'igbinary.so',
                'igbinary.compact_strings' => 'Off',
            };
        'mysqlnd':
            package_name => '',
            priority     => 10;
        'mysqli':
            package_name => "php${php_version}-mysql";
    }

    # XML
    php::extension{ [
        'dom',
        'simplexml',
        'xmlreader',
        'xmlwriter',
        'xsl',
    ]:
        package_name => '',
    }

    $fpm_workers_multiplier = lookup('php::fpm::fpm_workers_multiplier', {'default_value' => 1.5})
    $fpm_min_child = lookup('php::fpm::fpm_min_child', {'default_value' => 4})

    # This will add an fpm pool
    # We want a minimum of $fpm_min_child workers
    $num_workers = max(floor($facts['processors']['count'] * $fpm_workers_multiplier), $fpm_min_child)
    $request_timeout = lookup('php::fpm::request_timeout', {'default_value' => 60})
    php::fpm::pool { 'www':
        config => {
            'pm'                        => 'static',
            'pm.max_children'           => $num_workers,
            'request_terminate_timeout' => $request_timeout,
            'request_slowlog_timeout'   => 15,
        }
    }

    ssl::wildcard { 'matomo wildcard': }

    nginx::site { 'matomo.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/matomo/nginx.conf',
        monitor => true,
    }

    $salt = lookup('passwords::matomo::salt')
    $password = lookup('passwords::db::matomo')
    $noreply_password = lookup('passwords::mail::noreply')

    file { '/srv/matomo/config/config.ini.php':
        ensure  => present,
        content => template('matomo/config.ini.php.erb'),
        owner   => 'www-data',
        group   => 'www-data',
        require => Git::Clone['matomo'],
    }

    file { '/var/log/matomo':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0755',
        require => Git::Clone['matomo'],
    }

    # Install a systemd timer to run the Archive task periodically.
    # Running it once a day to avoid performance penalties on high trafficated websites
    # (https://matomo.org/faq/on-premise/how-to-set-up-auto-archiving-of-your-reports/#important-tips-for-medium-to-high-traffic-websites)
    $archiver_command = "/usr/bin/php /srv/matomo/console core:archive --url=\"https://matomo.miraheze.org/\""

    # Create concurrent archivers
    # https://matomo.org/faq/on-premise/how-to-set-up-auto-archiving-of-your-reports/
    $concurrent_hash = {
        '1' => '*-*-* 00/8:00:00',
        '2' => '*-*-* 00/8:01:00',
        '3' => '*-*-* 00/8:02:00',
    }
    $concurrent_hash.each | String $concurrent, String $interval | {
        systemd::timer::job { "matomo-archiver-${concurrent}":
            description       => "Runs the Matomo's archive process.",
            command           => "/bin/bash -c '${archiver_command}'",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => $interval,
            },
            logfile_basedir   => '/var/log/matomo',
            logfile_name      => "matomo-archive-${concurrent}.log",
            syslog_identifier => "matomo-archiver-${concurrent}",
            user              => 'www-data',
        }
    }

    ['last2', 'january'].each | $key | {
        $optimize_command = "/usr/bin/php /srv/matomo/console database:optimize-archive-tables ${key}"
        systemd::timer::job { "matomo-optimize-${key}":
            description       => "Runs the Matomo's Optimize ${key} process.",
            command           => "/bin/bash -c '${optimize_command}'",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => 'monthly',
            },
            logfile_basedir   => '/var/log/matomo',
            logfile_name      => "matomo-optimize-${key}.log",
            syslog_identifier => "matomo-optimize-${key}",
            user              => 'www-data',
        }
    }

    $queuedtracking_command = '/usr/bin/php /srv/matomo/console queuedtracking:process'
    systemd::timer::job { 'matomo-queuedtracking':
        description       => "Runs the Matomo's Plugin QueuedTracking process.",
        command           => "/bin/bash -c '${queuedtracking_command}'",
        interval          => {
            'start'    => 'OnCalendar',
            'interval' => '*-*-* *:*:00',
        },
        logfile_basedir   => '/var/log/matomo',
        logfile_name      => 'matomo-queuedtracking.log',
        syslog_identifier => 'matomo-queuedtracking',
        user              => 'www-data',
    }
}
