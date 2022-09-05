class roundcubemail (
    String $db_host               = 'db112.miraheze.org',
    String $db_name               = 'roundcubemail',
    String $db_user_name          = 'roundcubemail',
    String $db_user_password      = undef,
    String $roundcubemail_des_key = undef,
) {
    $config_cli = {
        'include_path'           => '".:/usr/share/php"',
        'error_log'              => 'syslog',
        'pcre.backtrack_limit'   => 5000000,
        'date.timezone'          => 'UTC',
        'display_errors'         => 'stderr',
        'memory_limit'           => lookup('php::cli::memory_limit', {'default_value' => '400M'}),
        'error_reporting'        => 'E_ALL & ~E_STRICT',
        'mysql'                  => { 'connect_timeout' => 3 },
        'default_socket_timeout' => 60,
    }

    $config_fpm = {
        'memory_limit' => lookup('php::fpm::memory_limit', {'default_value' => '512M'}),
        'display_errors' => 'Off',
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

    $core_extensions =  [
        'curl',
        'gd',
        'gmp',
        'intl',
        'mbstring',
        'ldap',
    ]

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
        'mysqlnd':
            package_name => '',
            priority     => 10;
        'mysqli':
            package_name => "php${php_version}-mysql";
        'pdo_mysql':
            package_name => '';
        'xml':
            package_name => "php${php_version}-xml",
            priority     => 15;
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

    $num_workers = max(floor($facts['virtual_processor_count'] * $fpm_workers_multiplier), $fpm_min_child)
    # These numbers need to be positive integers
    $max_spare = ceiling($num_workers * 0.3)
    $min_spare = ceiling($num_workers * 0.1)
    php::fpm::pool { 'www':
        config => {
            'pm'                   => 'dynamic',
            'pm.max_spare_servers' => $max_spare,
            'pm.min_spare_servers' => $min_spare,
            'pm.start_servers'     => $min_spare,
            'pm.max_children'      => $num_workers,
        }
    }

    ensure_packages([
        "php${php_version}-pspell",
        'composer',
        'nodejs',
    ])

    git::clone { 'roundcubemail':
        directory => '/srv/roundcubemail',
        origin    => 'https://github.com/roundcube/roundcubemail',
        branch    => '1.6.0', # Current stable
        owner     => 'www-data',
        group     => 'www-data',
    }

    file { '/srv/roundcubemail/composer.json':
        ensure  => present,
        source  => '/srv/roundcubemail/composer.json-dist',
        owner   => 'www-data',
        group   => 'www-data',
        replace => false,
        require => Git::Clone['roundcubemail'],
    }

    exec { 'roundcubemail_composer':
        command     => 'composer install --no-dev',
        creates     => '/srv/roundcubemail/vendor',
        cwd         => '/srv/roundcubemail',
        path        => '/usr/bin',
        environment => 'HOME=/srv/roundcubemail',
        user        => 'www-data',
        require     => File['/srv/roundcubemail/composer.json'],
    }

    exec { 'roundcubemail_js_deps':
        command     => 'bin/install-jsdeps.sh',
        creates     => '/srv/roundcubemail/skins/elastic/deps/less.min.js',
        cwd         => '/srv/roundcubemail',
        path        => '/usr/bin',
        environment => 'HOME=/srv/roundcubemail',
        user        => 'www-data',
        require     => Git::Clone['roundcubemail'],
    }

    file { '/srv/roundcubemail/config/config.inc.php':
        ensure  => present,
        content => template('roundcubemail/config.inc.php.erb'),
        owner   => 'www-data',
        group   => 'www-data',
        require => Git::Clone['roundcubemail'],
    }

    ssl::wildcard { 'roundcubemail wildcard': }

    nginx::site { 'mail':
        ensure => present,
        source => 'puppet:///modules/roundcubemail/mail.miraheze.org.conf',
    }

    nginx::site { 'roundcubemail':
        ensure => present,
        source => 'puppet:///modules/roundcubemail/roundcubemail.conf',
    }

    file { '/var/log/roundcubemail':
        ensure  => directory,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0640',
        require => Package['nginx'],
    }

    logrotate::conf { 'roundcubemail':
        ensure  => present,
        source  => 'puppet:///modules/roundcubemail/roundcubemail.logrotate.conf',
        require => File['/var/log/roundcubemail'],
    }

    monitoring::services { 'webmail.miraheze.org HTTPS':
        check_command => 'check_http',
        vars          => {
            http_ssl   => true,
            http_vhost => 'webmail.miraheze.org',
        },
     }
}
