# == Class: php::php_fpm
#
# This class makes it easy to integrate php-fpm into other puppet modules.
#
# === Parameters
#
# [*config*] A k => v hash of config keys and values we want to add to
#   the defaults.
#
# [*fpm_config*]
#
# [*fpm_min_child*] Sets the minimum childs for php-fpm, defaults to 4.
#
# [*fpm_pool_config*]
#
# [*version*] Contains the php version you want to use, defaults to php 7.2.
#
class php::php_fpm(
    Boolean $enable_fpm                       = lookup('php::enable_fpm', {'default_value' => true}),
    Hash $config                              = {},
    Hash $config_cli                          = {},
    Hash $fpm_config                          = {},
    Integer $fpm_min_child                    = 4,
    Hash $fpm_pool_config                     = {},
    VMlib::Php_version $version               = '7.2',
    Float $fpm_workers_multiplier             = lookup('php::php_fpm::fpm_workers_multiplier', {'default_value' => 1.5}),
    Integer $fpm_min_restart_threshold        = 1,
) {

    $base_config_cli = {
        'include_path'           => '".:/usr/share/php"',
        'error_log'              => 'syslog',
        'pcre.backtrack_limit'   => 5000000,
        'date.timezone'          => 'UTC',
        'display_errors'         => 'On',
        'error_reporting'        => 'E_ALL & ~E_STRICT',
        'mysql'                  => { 'connect_timeout' => 3 },
        'default_socket_timeout' => 60,
    }

    $base_config_fpm = {
        'opcache.enable'                  => 1,
        'opcache.interned_strings_buffer' => 30,
        'opcache.memory_consumption'      => 112,
        'opcache.max_accelerated_files'   => 20000,
        'opcache.max_wasted_percentage'   => 10,
        'opcache.validate_timestamps'     => 1,
        'opcache.revalidate_freq'         => 10,
        'display_errors'                  => 0,
        'session.upload_progress.enabled' => 0,
        'enable_dl'                       => 0,
    }

    if $enable_fpm {
        $_sapis = ['cli', 'fpm']
        $_config = {
            'cli' => merge($base_config_cli, $config_cli),
            'fpm' => merge($config_cli, $base_config_fpm, $fpm_config)
        }
        # Add systemd override for php-fpm, that should prevent a reload
        # if the fpm config files are broken.
        # This should prevent us from shooting our own foot as happened before.
        systemd::unit { "php${version}-fpm.service":
            ensure   => present,
            content  => template('php/php-fpm-systemd-override.conf.erb'),
            override => true,
            restart  => false,
        }
    } else {
        $_sapis = ['cli']
        $_config = {
            'cli' => merge($base_config_cli, $config_cli),
        }
    }
    # Install the runtime
    class { 'php':
        ensure         => present,
        version        => $version,
        sapis          => $_sapis,
        config_by_sapi => $_config,
    }

    $core_extensions =  [
        'bcmath',
        'curl',
        'gd',
        'gmp',
        'intl',
        'ldap',
        'mbstring',
        'zip',
    ]

    $core_extensions.each |$extension| {
        php::extension { $extension:
            package_name => "php${version}-${extension}",
        }
    }

    php::extension { [
        'apcu',
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
            package_name => "php${version}-xml",
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
        'imagick':
            package_name => 'php-imagick';
        'mysqli':
            package_name => "php${version}-mysql",
            config       => {
                'extension'                 => 'mysqli.so',
                'mysqli.allow_local_infile' => 'Off',
            }
            ;
        'dba':
            package_name => "php${version}-dba",
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

    require_package("php${version}-dev", 'php-mail', 'php-mail-mime', 'php-mailparse', 'php-pear')

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
        $base_fpm_config = {
            'emergency_restart_interval'  => '60s',
            'emergency_restart_threshold' => max($facts['virtual_processor_count'], $fpm_min_restart_threshold),
            'error_log'                   => 'syslog',
        }

        class { '::php::fpm':
            ensure  => present,
            config  => merge($base_fpm_config, $fpm_config),
        }

        $num_workers =  max(floor($facts['virtual_processor_count'] * $fpm_workers_multiplier), $fpm_min_child)
        # These numbers need to be positive integers
        $max_spare = ceiling($num_workers * 0.3)
        $min_spare = ceiling($num_workers * 0.1)

        $base_fpm_pool_config = {
            'pm'                        => 'dynamic',
            'pm.max_spare_servers'      => $max_spare,
            'pm.min_spare_servers'      => $min_spare,
            'pm.start_servers'          => $min_spare,
            'pm.max_children'           => $num_workers,
            'request_terminate_timeout' => 59,
        }

        php::fpm::pool { 'www':
            config => merge($base_fpm_pool_config, $fpm_pool_config),
        }
    }
}
