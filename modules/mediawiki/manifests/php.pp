# mediawiki::php
class mediawiki::php (
    $php_fpm_childs = hiera('mediawiki::php::fpm::childs', 6),
    $fpm_min_restart_threshold = hiera('mediawiki::php::fpm::fpm_min_restart_threshold', 6),
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
        'fpm_pool_config' => {
            'request_terminate_timeout_track_finished' => 'yes',
        },
        'fpm_min_child' => $php_fpm_childs,
        'fpm_min_restart_threshold' => $fpm_min_restart_threshold,
        'version' => $php_version
    })

    $profiling_ensure =  $use_tideways ? {
        true    => 'present',
        default => 'absent'
    }

    if $php_version == '7.3' {
        file { '/usr/lib/php/20180731/tideways_xhprof.so':
            ensure => $profiling_ensure,
            mode   => '0755',
            source => 'puppet:///modules/mediawiki/php/tideways_xhprof.so',
        }

        php::extension { 'tideways-xhprof':
            ensure   => $profiling_ensure,
            package_name => '',
            priority => 30,
            sapis    => ['fpm'],
            config   => {
                'extension'                       => 'tideways_xhprof.so',
                'tideways_xhprof.clock_use_rdtsc' => '0',
            },
            require  => File['/usr/lib/php/20180731/tideways_xhprof.so'],
        }
    } else {
        php::extension { 'tideways':
            ensure   => $profiling_ensure,
            priority => 30,
            sapis    => ['fpm'],
            config   => {
                'extension'                       => 'tideways.so',
                'tideways_xhprof.clock_use_rdtsc' => '0',
            }
        }
    }
}
