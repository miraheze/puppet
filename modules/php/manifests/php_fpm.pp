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
    Hash $config                              = {},
    Hash $config_cli                          = {},
    Hash $fpm_config                          = {},
    Integer $fpm_min_child                    = 4,
    Hash $fpm_pool_config                     = {},
    Enum['7.0', '7.1', '7.2', '7.3', '7.4'] $version = '7.2',
    Float $fpm_workers_multiplier = lookup('php::php_fpm::fpm_workers_multiplier', {'default_value' => 1.5}),
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

    # Add systemd override for php-fpm, that should prevent a reload
    # if the fpm config files are broken.
    # This should prevent us from shooting our own foot as happened before.
    systemd::unit { "php${version}-fpm.service":
        ensure   => present,
        content  => template('php/php-fpm-systemd-override.conf.erb'),
        override => true,
        restart  => false,
    }

    # Install the runtime
    class { '::php':
        ensure         => present,
        version        => $version,
        sapis          => ['cli', 'fpm'],
        config_by_sapi => {
            'cli' => merge($base_config_cli, $config_cli),
            'fpm' => merge($base_config_cli, $base_config_fpm, $config),
        },
    }

    $core_extensions =  [
        'apcu',
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

    php::extension { 'redis':
        package_name => "php-redis",
    }

    if $version == '7.3' {
        require_package('liblua5.1-0')

        # make sure to rebuild against the selected php version
        file { '/usr/lib/php/20180731/luasandbox.so':
            ensure => present,
            source => "puppet:///modules/php/luasandbox/${version}.luasandbox.so",
        }

        file { '/usr/lib/php/20180731/wikidiff2.so':
            ensure => present,
            source => "puppet:///modules/php/wikidiff2/wikidiff2.so",
        }

        php::extension {
            'luasandbox':
                package_name => '';
            'wikidiff2':
                package_name => '';
        }
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
        'wddx',
    ]:
        package_name => '',
    }

    $base_fpm_config = {
        'emergency_restart_interval'  => '60s',
        'emergency_restart_threshold' => max($facts['virtual_processor_count'], $fpm_min_restart_threshold),
        'error_log'                   => 'syslog',
    }

    if $facts['virtual'] != 'openvz' {
          $base_fpm_config_kvm = {
                'process.priority' => -19,
          }
    } else {
        $base_fpm_config_kvm = {}
    }

    class { '::php::fpm':
        ensure  => present,
        config  => merge($base_fpm_config, $base_fpm_config_kvm, $fpm_config),
    }

    $num_workers =  max(floor($facts['virtual_processor_count'] * $fpm_workers_multiplier), $fpm_min_child)

    $base_fpm_pool_config = {
        'pm'                        => 'static',
        'pm.max_children'           => $num_workers,
        'request_terminate_timeout' => 180,
    }

    php::fpm::pool { 'www':
        config => merge($base_fpm_pool_config, $fpm_pool_config),
    }
}
