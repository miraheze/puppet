# mediawiki::php
class mediawiki::php (
    $php_fpm_childs = hiera('mediawiki::php::fpm::childs', 6),
    $php_version = hiera('php::php_version', '7.2'),
    Optional[Boolean] $use_tideways = undef,
) {
    ensure_resource_duplicate('class', '::php::php_fpm', {
        'config'  => {
            'display_errors'            => 'Off',
            'error_log'                 => '/var/log/mediawiki/debuglogs/php-error.log',
            'error_reporting'           => 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
            'log_errors'                => 'On',
            'opcache'                   => {
                'enable'                  => 1,
                'interned_strings_buffer' => 40,
                'memory_consumption'      => 200,
                'max_accelerated_files'   => 20000,
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
        'fpm_min_restart_threshold' => 4,
        'version' => $php_version
    })

    if $use_tideways {
        php::extension { 'tideways':
            ensure  => present,
            sapis   => [ 'fpm' ]
        }
    }
}
