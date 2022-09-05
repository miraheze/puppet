class icingaweb2 (
    String $db_host              = 'db112.miraheze.org',
    String $db_name              = 'icingaweb2',
    String $db_user_name         = 'icingaweb2',
    String $db_user_password     = undef,
    String $ido_db_host          = 'db112.miraheze.org',
    String $ido_db_name          = 'icinga',
    String $ido_db_user_name     = 'icinga2',
    String $ido_db_user_password = undef,
    String $icinga_api_password  = undef,
    String $ldap_password        = undef,
) {

    if ! defined(Class['::icinga2']) {
        fail('You must include the icinga2 base class before using any icingaweb2 feature class!')
    }

    $fpm_config = {
        'include_path'                    => '".:/usr/share/php"',
        'error_log'                       => 'syslog',
        'pcre.backtrack_limit'            => 5000000,
        'date.timezone'                   => 'UTC',
        'display_errors'                  => 0,
        'error_reporting'                 => 'E_ALL & ~E_STRICT',
        'log_errors'                      => 'On',
        'memory_limit'                    => lookup('php::fpm::memory_limit', {'default_value' => '512M'}),
        'mysql'                           => { 'connect_timeout' => 3 },
        'default_socket_timeout'          => 60,
        'session.upload_progress.enabled' => 0,
        'enable_dl'                       => 0,
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

    package { [ 'icingaweb2', 'icingaweb2-module-monitoring',
                'icingaweb2-module-doc', 'icingacli' ]:
        ensure  => present,
        require => Apt::Source['icinga-stable-release'],
    }

    file { '/etc/icingaweb2':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'icingaweb2',
        mode    => '2755',
        require => Package['icingaweb2'],
    }

    file { '/etc/icingaweb2/authentication.ini':
        ensure  => present,
        content => template('icingaweb2/authentication.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/config.ini':
        ensure  => present,
        source  => 'puppet:///modules/icingaweb2/config.ini',
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/groups.ini':
        ensure  => present,
        content => template('icingaweb2/groups.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/resources.ini':
        ensure  => present,
        content => template('icingaweb2/resources.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/roles.ini':
        ensure  => present,
        content => template('icingaweb2/roles.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
    }

    file { '/etc/icingaweb2/enabledModules':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'icingaweb2',
        mode    => '2755',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/enabledModules/doc':
        ensure  => 'link',
        target  => '/usr/share/icingaweb2/modules/doc',
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/enabledModules'],
    }

    file { '/etc/icingaweb2/enabledModules/monitoring':
        ensure  => 'link',
        target  => '/usr/share/icingaweb2/modules/monitoring',
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/enabledModules'],
    }

    file { '/etc/icingaweb2/enabledModules/setup':
        ensure  => 'link',
        target  => '/usr/share/icingaweb2/modules/setup',
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/enabledModules'],
    }

    file { '/etc/icingaweb2/enabledModules/translation':
        ensure  => 'link',
        target  => '/usr/share/icingaweb2/modules/translation',
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/enabledModules'],
    }

    file { '/etc/icingaweb2/modules':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'icingaweb2',
        mode    => '2755',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/modules/monitoring':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'icingaweb2',
        mode    => '2755',
        require => File['/etc/icingaweb2/modules'],
    }

    file { '/etc/icingaweb2/modules/monitoring/backends.ini':
        ensure  => present,
        content => template('icingaweb2/backends.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/modules/monitoring'],
    }

    file { '/etc/icingaweb2/modules/monitoring/commandtransports.ini':
        ensure  => present,
        content => template('icingaweb2/commandtransports.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/modules/monitoring'],
    }

    ssl::wildcard { 'icingaweb2 wildcard': }

    nginx::site { 'icinga2':
        ensure => present,
        source => 'puppet:///modules/icingaweb2/icinga2.conf',
    }

    monitoring::services { 'icinga.miraheze.org HTTPS':
        check_command => 'check_http',
        vars          => {
            http_ssl   => true,
            http_vhost => 'icinga.miraheze.org',
        },
     }
}
