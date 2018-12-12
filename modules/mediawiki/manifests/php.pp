# mediawiki::php
class mediawiki::php {

    $php_version = hiera('php::php_version', '7.2')

    if hiera('use_new_php_module', false) {
        $fpm_config = {
            'opcache'                   => {
                'enable'                  => 1,
                'memory_consumption'      => 256,
                'interned_strings_buffer' => 64,
                'max_accelerated_files'   => 32531,
                'revalidate_freq'         => 60,
            },
            'max_execution_time'  => 240,
            'post_max_size'       => '250M',
            'track_errors'        => 'Off',
            'upload_max_filesize' => '250M',
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
            'mail':
                package_name => 'php-mail';
            'mailparse':
                package_name => 'php-mailparse';
            'pear':
                package_name => 'php-pear';
            'mysqlnd':
                package_name => "php${php_version}-mysqlnd",
                priority     => 15;
            'mysqli':
                package_name => "php${php_verision}-mysql";
            'dba':
                package_name => "php${php_version}-dba",
        }

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
