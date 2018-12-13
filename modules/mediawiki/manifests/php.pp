# mediawiki::php
class mediawiki::php {
    if hiera('use_new_php_module', true) {
        ensure_resource_duplicate('class', '::php::php_fpm', {
            'version' => hiera('php::php_version', '7.2'),
            'config'  => {
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
            },
        })
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
