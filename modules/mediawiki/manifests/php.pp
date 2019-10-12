# mediawiki::php
class mediawiki::php (
    $php_fpm_childs = hiera('mediawiki::php::fpm::childs', 16),
    $php_version = hiera('php::php_version', '7.2'),
) {
    ensure_resource_duplicate('class', '::php::php_fpm', {
        'config'  => {
            'display_errors'            => 'Off',
            'error_log'                 => '/var/log/mediawiki/debuglogs/php-error.log',
            'error_reporting'           => 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
            'log_errors'                => 'On',
            'opcache'                   => {
                'enable'                  => 1,
                'interned_strings_buffer' => 50,
                'memory_consumption'      => 300,
                'max_accelerated_files'   => 24000,
                'max_wasted_percentage'   => 10,
                'validate_timestamps'     => 1,
                'revalidate_freq'         => 10,
            },
            'enable_dl'           => 0,
            'post_max_size'       => '250M',
            'register_argc_argv'  => 'Off',
            'request_order'       => 'GP',
            'track_errors'        => 'Off',
            'upload_max_filesize' => '250M',
            'variables_order'     => 'GPCS',
        },
        'fpm_min_child' => $php_fpm_childs,
        'version' => $php_version
    })
}
