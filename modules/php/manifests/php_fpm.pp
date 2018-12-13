class php::php_fpm(
    Enum['7.0', '7.1', '7.2', '7.3'] $version = '7.2',
    Hash $config                              = {},
) {

    # Install the runtime
    class { '::php':
        ensure         => present,
        version        => $version,
        sapis          => ['cli', 'fpm'],
        config_by_sapi => {
            'fpm' => $config,
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

    class { '::php::fpm':
        ensure  => present,
        config  => {
            'emergency_restart_interval'  => '60s',
            'emergency_restart_threshold' => $facts['processors']['count'],
            'process.priority'            => -19,
        },
        require => Apt::Source['php_apt'],
    }

    $num_workers = max(floor($facts['processors']['count'] * 1.5), 6)
    # These numbers need to be positive integers
    $max_spare = ceiling($num_workers * 0.3)
    $min_spare = ceiling($num_workers * 0.1)
    php::fpm::pool { 'www':
        config => {
            'pm'                        => 'dynamic',
            'pm.max_spare_servers'      => $max_spare,
            'pm.min_spare_servers'      => $min_spare,
            'pm.start_servers'          => $min_spare,
            'pm.max_children'           => $num_workers,
            'request_terminate_timeout' => 230,
        }
    }
}
