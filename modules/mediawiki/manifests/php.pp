# mediawiki::php
class mediawiki::php {

    $php_version = hiera('php::php_version', '7.2')

    if hiera('use_new_php_module', true) {
        $fpm_config = {
            'display_errors'            => 'Off',
            'error_log'                 => '/var/log/mediawiki/debuglogs/php-error.log',
            'error_reporting'           => 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
            'log_errors'                => 'On',
            'max_execution_time'        => 230,
            'opcache'                   => {
                'enable'                  => 1,
                'memory_consumption'      => 256,
                'interned_strings_buffer' => 64,
                'max_accelerated_files'   => 32531,
                'revalidate_freq'         => 60,
            },
            'post_max_size'       => '250M',
            'register_argc_argv'  => 'Off',
            'request_order'       => 'GP',
            'track_errors'        => 'Off',
            'upload_max_filesize' => '250M',
            'variables_order'     => 'GPCS',
        }

        # Install the runtime
        class { '::php':
            ensure         => present,
            version        => $php_verision,
            sapis          => ['cli', 'fpm'],
            config_by_sapi => {
                'fpm' => $fpm_config,
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
                package_name => "php${php_version}-${extension}",
                require      => Apt::Source['php_apt'],
            }
        }

        # Extensions that require configuration.
        php::extension {
            'xml':
                package_name => "php${php_version}-xml",
                priority     => 15;
            'igbinary':
                config   => {
                    'extension'       => 'igbinary.so',
                    'compact_strings' => 'Off',
                };
            'imagick':
                package_name => 'php-imagick';
            'mysqlnd':
                package_name => "php${php_version}-mysqlnd",
                priority     => 15;
            'mysqli':
                package_name => "php${php_verision}-mysql";
            'dba':
                package_name => "php${php_version}-dba",
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
    } else {
        include ::php_old

        file { '/etc/php/7.2/fpm/php-fpm.conf':
            ensure  => 'present',
            mode    => '0755',
            source  => 'puppet:///modules/mediawiki/php/php-fpm-7.2.conf',
            require => Package['php7.2-fpm'],
            notify  => Service['php7.2-fpm'],
        }

        file { '/etc/php/7.2/fpm/php.ini':
            ensure  => present,
            mode    => '0755',
            source  => 'puppet:///modules/mediawiki/php/php-7.2.ini',
            require => Package['php7.2-fpm'],
            notify  => Service['php7.2-fpm'],
        }
    }
}
