# mediawiki::php
class mediawiki::php {
    ensure_resource_duplicate('class', '::php::php_fpm', {
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
        # We double this so that it's 4 x 3
        'fpm_min_child' => 12,
        'version' => hiera('php::php_version', '7.2'),
    })
}
