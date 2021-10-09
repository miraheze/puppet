# mediawiki::php
class mediawiki::php (
    Integer $php_fpm_childs = lookup('mediawiki::php::fpm::childs', {'default_value' => 26}),
    Integer $fpm_min_restart_threshold = lookup('mediawiki::php::fpm::fpm_min_restart_threshold', {'default_value' => 6}),
    String $php_version = lookup('php::php_version', {'default_value' => '7.2'}),
    Boolean $use_tideways = lookup('mediawiki::php::use_tideways', {'default_value' => false}),
) {
    
    if !defined(Class['php::php_fpm']) {
        class { 'php::php_fpm':
            config  => {
                'apc'                       => {
                    'shm_size' => '1024M'
                },
                'display_errors'            => 'Off',
                'error_log'                 => 'syslog',
                'error_reporting'           => 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
                'log_errors'                => 'On',
                'memory_limit'              => '512M',
                'opcache'                   => {
                    'enable'                  => 1,
                    'interned_strings_buffer' => 50,
                    'memory_consumption'      => 512,
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
            fpm_pool_config => {
                'request_terminate_timeout_track_finished' => 'yes',
            },
            fpm_min_child => $php_fpm_childs,
            fpm_min_restart_threshold => $fpm_min_restart_threshold,
            version => $php_version,
            # Make sure that php is installed before composer is ran
            before => [
                Class['mediawiki::servicessetup'],
            ],
        }
    }

    $profiling_ensure =  $use_tideways ? {
        true    => 'present',
        default => 'absent'
    }

    # Built on test3
    # Follow https://support.tideways.com/documentation/reference/tideways-xhprof/tideways-xhprof-extension.html
    if $php_version == '7.3' {
        # Compatiable with php 7.3 only
        file { '/usr/lib/php/20180731/tideways_xhprof.so':
            ensure => $profiling_ensure,
            mode   => '0755',
            source => 'puppet:///modules/mediawiki/php/tideways_xhprof_7_3.so',
            before => Php::Extension['tideways-xhprof'],
        }
    } else {
        # Compatiable with php 7.4 only
        file { '/usr/lib/php/20190902/tideways_xhprof.so':
            ensure => $profiling_ensure,
            mode   => '0755',
            source => 'puppet:///modules/mediawiki/php/tideways_xhprof_7_4.so',
            before => Php::Extension['tideways-xhprof'],
        }
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
