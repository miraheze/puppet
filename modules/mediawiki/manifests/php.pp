# === Class mediawiki::php
class mediawiki::php (
    Float $fpm_workers_multiplier      = lookup('mediawiki::php::fpm::fpm_workers_multiplier', {'default_value' => 1.5}),
    Integer $php_fpm_childs            = lookup('mediawiki::php::fpm::childs', {'default_value' => 26}),
    Integer $cli_max_memory            = lookup('mediawiki::php::cli_max_memory', {'default_value' => 256}),
    Integer $request_timeout           = lookup('mediawiki::php::request_timeout', {'default_value' => 60}),
    VMlib::Php_version $php_version    = lookup('php::php_version', {'default_value' => '7.4'}),
    Boolean $enable_fpm                = lookup('mediawiki::php::enable_fpm', {'default_value' => true}),
    Boolean $enable_request_profiling  = lookup('mediawiki::php::enable_request_profiling', {'default_value' => false}),
    Optional[Hash] $fpm_config         = lookup('mediawiki::php::fpm_config', {default_value => undef}),
) {
    
    $config_cli = {
        'include_path'           => '".:/usr/share/php"',
        'error_log'              => 'syslog',
        'pcre.backtrack_limit'   => 5000000,
        'date.timezone'          => 'UTC',
        'display_errors'         => 'stderr',
        'memory_limit'           => "${$cli_max_memory}M",
        'error_reporting'        => 'E_ALL & ~E_STRICT',
        'mysql'                  => { 'connect_timeout' => 3 },
        'default_socket_timeout' => 60,
    }

    # Custom config for php-fpm
    $base_config_fpm = {
        'opcache.enable'                  => 1,
        'opcache.interned_strings_buffer' => 50,
        'opcache.memory_consumption'      => 128,
        'opcache.max_accelerated_files'   => 24000,
        'opcache.max_wasted_percentage'   => 10,
        'opcache.validate_timestamps'     => 1,
        'opcache.revalidate_freq'         => 10,
        'display_errors'                  => 0,
        'session.upload_progress.enabled' => 0,
        'enable_dl'                       => 0,
        'apc.shm_size'                    => 256,
        'rlimit_core'                     => 0,
    }
    if $enable_fpm {
        $_sapis = ['cli', 'fpm']
        $_config = {
            'cli' => $config_cli,
            'fpm' => merge($config_cli, $base_config_fpm, $fpm_config)
        }
        # Add systemd override for php-fpm, that should prevent a reload
        # if the fpm config files are broken.
        systemd::unit { "php${php_version}-fpm.service":
            ensure   => present,
            content  => template('php/php-fpm-systemd-override.conf.erb'),
            override => true,
            restart  => false,
        }
    } else {
        $_sapis = ['cli']
        $_config = {
            'cli' => $config_cli,
        }
    }
    # Install the runtime
    class { 'php':
        ensure         => present,
        version        => $php_version,
        sapis          => $_sapis,
        config_by_sapi => $_config,
    }

    # Extensions that need no custom settings

    # First, extensions provided as core extensions; these are version-specific
    # and are provided as php$version-$extension
    #
    $core_extensions =  [
        'bcmath',
        'bz2',
        'curl',
        'gd',
        'gmp',
        'intl',
        'mbstring',
    ]

    $core_extensions.each |$extension| {
        php::extension { $extension:
            package_name => "php${php_version}-${extension}"
        }
    }
    # Extensions that are installed with package-name php-$extension and, based
    # on the php version selected above, will install the proper extension
    # version based on apt priorities.
    # php-luasandbox and  php-wikidiff2 are special cases as the package is *not*
    # compatible with all supported PHP versions.
    # Technically, it would be needed to inject ensure => latest in the packages,
    # but we prefer to handle the transitions with other tools than puppet.
    php::extension { [
        'apcu',
        'geoip',
        'msgpack',
        'redis',
        'luasandbox',
        'wikidiff2',
    ]:
        ensure => present
    }

    # Extensions that require configuration.
    php::extension {
        'xml':
            package_name => "php${php_version}-xml",
            priority     => 15;
        'memcached':
            priority => 25,
            config   => {
                'extension'                   => 'memcached.so',
                'memcached.serializer'        => 'php',
                'memcached.store_retry_count' => '0'
            };
        'igbinary':
            config   => {
                'extension'                => 'igbinary.so',
                'igbinary.compact_strings' => 'Off',
            };
        'mysqli':
            package_name => "php${php_version}-mysql",
            config       => {
                'extension'                 => 'mysqli.so',
                'mysqli.allow_local_infile' => 'Off',
            }
            ;

        'dba':
            package_name => "php${php_version}-dba",
    }

    # Additional config files are needed by some extensions, add them
    # MySQL
    php::extension {
        default:
            package_name => '',;
        'pdo_mysql':
            ;
        'mysqlnd':
            priority => 10,
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

    ### FPM configuration
    # You can check all configuration options at
    # http://php.net/manual/en/install.fpm.configuration.php
    if $enable_fpm {
        class { 'php::fpm':
            ensure => present,
            config => {
                'emergency_restart_interval'  => '60s',
                'emergency_restart_threshold' => $facts['virtual_processor_count'],
                'process.priority'            => -19,
            }
        }

        # This will add an fpm pool listening on port 8000
        # We want a minimum of 4 workers
        $num_workers = max(floor($facts['virtual_processor_count'] * $fpm_workers_multiplier), 4)
        php::fpm::pool { 'www':
            port   => 8000,
            config => {
                'pm'                        => 'static',
                'pm.max_children'           => $num_workers,
                'request_terminate_timeout' => $request_timeout,
                'request_slowlog_timeout'   => 15,
            }
        }
    }

    # Install tideways-xhprof
    $profiling_ensure = $enable_request_profiling ? {
        true    => 'present',
        default => 'absent'
    }

    # Follow https://support.tideways.com/documentation/reference/tideways-xhprof/tideways-xhprof-extension.html
    file { '/usr/lib/php/20190902/tideways_xhprof.so':
        ensure => $profiling_ensure,
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/php/tideways_xhprof.so',
        before => Php::Extension['tideways-xhprof'],
    }

    php::extension { 'tideways-xhprof':
        ensure   => $profiling_ensure,
        priority => 30,
        config   => {
            'extension'                       => 'tideways_xhprof.so',
            'tideways_xhprof.clock_use_rdtsc' => '0',
        }
    }

    # Set the default interpreter to php7
    $cli_path = "/usr/bin/php${php_version}"
    $pkg = "php${php_version}-cli"
    alternatives::select { 'php':
        path    => $cli_path,
        require => Package[$pkg],
    }
}
