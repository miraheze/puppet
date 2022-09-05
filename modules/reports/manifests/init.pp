# class: reports
class reports {
    ensure_packages(['mariadb-client', 'composer'])

    git::clone { 'TSPortal':
        directory => '/srv/TSPortal',
        origin    => 'https://github.com/miraheze/TSPortal',
        branch    => 'v7',
        owner     => 'www-data',
        group     => 'www-data',
    }

    exec { 'reports_composer':
        command     => 'composer install --no-dev',
        creates     => '/srv/TSPortal/vendor',
        cwd         => '/srv/TSPortal',
        path        => '/usr/bin',
        environment => 'HOME=/srv/TSPortal',
        user        => 'www-data',
        require     => Git::Clone['TSPortal'],
    }

    $config_cli = {
        'include_path'           => '".:/usr/share/php"',
        'error_log'              => 'syslog',
        'pcre.backtrack_limit'   => 5000000,
        'date.timezone'          => 'UTC',
        'display_errors'         => 'stderr',
        'memory_limit'           => lookup('php::cli::memory_limit', {'default_value' => '512M'}),
        'error_reporting'        => 'E_ALL & ~E_STRICT',
        'mysql'                  => { 'connect_timeout' => 3 },
        'default_socket_timeout' => 60,
    }

    $config_fpm = {
        'memory_limit' => lookup('php::fpm::memory_limit', {'default_value' => '512M'}),
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

    $php_version = lookup('php::php_version', {'default_value' => '7.4'})

    # Install the runtime
    class { '::php':
        ensure         => present,
        version        => $php_version,
        sapis          => ['cli', 'fpm'],
        config_by_sapi => {
            'cli' => $config_cli,
            'fpm' => merge($config_cli, $config_fpm),
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

    class { '::php::fpm':
        ensure => present,
        config => {
            'emergency_restart_interval'  => '60s',
            'emergency_restart_threshold' => $facts['virtual_processor_count'],
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
        'pdo_mysql':
            package_name => '';
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
    $num_workers = max(floor($facts['virtual_processor_count'] * $fpm_workers_multiplier), $fpm_min_child)
    $request_timeout = lookup('php::fpm::request_timeout', {'default_value' => 60})
    php::fpm::pool { 'www':
        config => {
            'pm'                        => 'static',
            'pm.max_children'           => $num_workers,
            'request_terminate_timeout' => $request_timeout,
            'request_slowlog_timeout'   => 15,
        }
    }

    ssl::wildcard { 'reports wildcard': }

    nginx::site { 'reports.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/reports/nginx.conf',
        monitor => true,
    }

    $salt = lookup('passwords::piwik::salt')
    $password = lookup('passwords::db::reports')
    $app_key = lookup('reports::app_key')
    $reports_mediawiki_identifier = lookup('reports::reports_mediawiki_identifier')
    $reports_mediawiki_secret = lookup('reports::reports_mediawiki_secret')
    $reports_discord_webhook = lookup('reports::reports_discord_webhook')

    file { '/srv/TSPortal/.env':
        ensure  => present,
        content => template('reports/.env.erb'),
        owner   => 'www-data',
        group   => 'www-data',
        require => Git::Clone['TSPortal'],
    }
}
