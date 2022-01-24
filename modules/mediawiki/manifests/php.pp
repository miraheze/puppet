# === Class mediawiki::php
class mediawiki::php (
    Integer $php_fpm_childs            = lookup('mediawiki::php::fpm::childs', {'default_value' => 26}),
    Integer $fpm_min_restart_threshold = lookup('mediawiki::php::fpm::fpm_min_restart_threshold', {'default_value' => 6}),
    Integer $fpm_max_memory            = lookup('mediawiki::php::fpm::fpm_max_memory', {'default_value' => 512}),
    VMlib::Php_version $php_version    = lookup('php::php_version', {'default_value' => '7.4'}),
    Boolean $use_tideways              = lookup('mediawiki::php::use_tideways', {'default_value' => false}),
) {
    
    if !defined(Class['php::php_fpm']) {
        class { 'php::php_fpm':
            config  => {
                'apc'                       => {
                    'shm_size' => '256M'
                },
                'display_errors'            => 'Off',
                'error_log'                 => 'syslog',
                'error_reporting'           => 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
                'log_errors'                => 'On',
                'memory_limit'              => "${$fpm_max_memory}M",
                'opcache'                   => {
                    'enable'                  => 1,
                    'interned_strings_buffer' => 50,
                    'memory_consumption'      => $fpm_max_memory,
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
            fpm_min_child => $php_fpm_childs,
            fpm_min_restart_threshold => $fpm_min_restart_threshold,
            version => $php_version,
        }
    }

    $profiling_ensure = $use_tideways ? {
        true    => 'present',
        default => 'absent'
    }

    # Follow https://support.tideways.com/documentation/reference/tideways-xhprof/tideways-xhprof-extension.html
    file { '/usr/lib/php/20190902/tideways_xhprof.so':
        ensure => $profiling_ensure,
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/php/tideways_xhprof.so',
        before => Php::Extension['tideways-xhprof'],
    }

    php::extension { 'tideways-xhprof':
        ensure   => $profiling_ensure,
        package_name => '',
        priority => 30,
        config   => {
            'extension'                       => 'tideways_xhprof.so',
            'tideways_xhprof.clock_use_rdtsc' => '0',
        }
    }
}
