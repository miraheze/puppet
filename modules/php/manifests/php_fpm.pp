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
# [*fpm_max_child*] Sets the maximum childs for php-fpm, defaults to 8.
#
# [*fpm_pool_config*]
#
# [*version*] Contains the php version you want to use, defaults to php 7.2.
#
class php::php_fpm(
    Hash $config                              = {},
    Hash $fpm_config                          = {},
    Integer $fpm_max_child                    = 8,
    Hash $fpm_pool_config                     = {},
    Enum['7.0', '7.1', '7.2', '7.3'] $version = '7.2',
) {

    $base_config = {
        'error_log' => '/var/log/php/php.log',
    }

    # Install the runtime
    class { '::php':
        ensure         => present,
        version        => $version,
        sapis          => ['cli', 'fpm'],
        config_by_sapi => {
            'fpm' => merge($base_config, $config),
        },
    }

    $core_extensions =  [
        'apcu',
        'curl',
        'bcmath',
        'gd',
        'gmp',
        'intl',
        'mbstring',
        'redis',
        'zip',
    ]

    $core_extensions.each |$extension| {
        php::extension { $extension:
            package_name => "php${version}-${extension}",
            require      => Apt::Source['php_apt'],
        }
    }

    # Extensions that require configuration.
    php::extension {
        'xml':
            package_name => "php${version}-xml",
            priority     => 15;
        'igbinary':
            config   => {
                'extension'       => 'igbinary.so',
                'compact_strings' => 'Off',
            };
        'imagick':
            package_name => 'php-imagick';
        'mysqlnd':
            package_name => "php${version}-mysqlnd",
            priority     => 15;
        'mysqli':
            package_name => "php${version}-mysql";
        'dba':
            package_name => "php${version}-dba",
    }

    require_package('php-luasandbox', 'php-mail', 'php-mailparse', 'php-pear')

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
        'emergency_restart_threshold' => $facts['processors']['count'],
        'error_log'                   => '/var/log/php7.2-fpm.log',
        'process.priority'            => -19,
    }

    class { '::php::fpm':
        ensure  => present,
        config  => merge($base_fpm_config, $fpm_config),
        require => Apt::Source['php_apt'],
    }

    $num_workers = max(floor($facts['processors']['count'] * 1.5), 6)
    # These numbers need to be positive integers
    $max_spare = ceiling($num_workers * 0.3)
    $min_spare = ceiling($num_workers * 0.1)

    $base_fpm_pool_config = {
        'pm'                        => 'dynamic',
        'pm.max_spare_servers'      => $max_spare,
        'pm.min_spare_servers'      => $min_spare,
        'pm.start_servers'          => $min_spare,
        'pm.max_children'           => $num_workers,
        'request_terminate_timeout' => 230,
    }

    php::fpm::pool { 'www':
        config => merge($base_fpm_pool_config, $fpm_pool_config),
    }

    file { '/var/log/php':
        ensure => directory,
        owner  => 'www-data',
        group  => 'www-data',
    }

    logrotate::conf { 'php-fpm':
        ensure => present,
        source => 'puppet:///modules/php/php-fpm-logrotate.conf',
    }
}
