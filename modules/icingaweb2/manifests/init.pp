class icingaweb2 (
    String $db_host              = 'db13.miraheze.org',
    String $db_name              = 'icingaweb2',
    String $db_user_name         = 'icingaweb2',
    String $db_user_password     = undef,
    String $ido_db_host          = 'db13.miraheze.org',
    String $ido_db_name          = 'icinga',
    String $ido_db_user_name     = 'icinga2',
    String $ido_db_user_password = undef,
    String $icinga_api_password  = undef,
    String $ldap_password        = undef,
) {

    if ! defined(Class['::icinga2']) {
        fail('You must include the icinga2 base class before using any icingaweb2 feature class!')
    }

    if !defined(Class['php::php_fpm']) {
        class { 'php::php_fpm':
            config  => {
                'display_errors'            => 'Off',
                'error_reporting'           => 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
                'log_errors'                => 'On',
                'memory_limit'              => lookup('php::fpm::memory_limit', {'default_value' => '512M'}),
                'opcache'                   => {
                    'enable'                  => 1,
                    'interned_strings_buffer' => 30,
                    'memory_consumption'      => 112,
                    'max_accelerated_files'   => 20000,
                    'max_wasted_percentage'   => 10,
                    'validate_timestamps'     => 1,
                    'revalidate_freq'         => 10,
                },
                'enable_dl'           => 0,
                'post_max_size'       => '60M',
                'register_argc_argv'  => 'Off',
                'request_order'       => 'GP',
                'track_errors'        => 'Off',
                'upload_max_filesize' => '100M',
                'variables_order'     => 'GPCS',
            },
            config_cli => {
                'memory_limit' => lookup('php::cli::memory_limit', {'default_value' => '400M'}),
            },
            fpm_min_child => 4,
            version => lookup('php::php_version', {'default_value' => '7.3'}),
        }
    }

    package { [ 'icingaweb2', 'icingaweb2-module-monitoring',
                'icingaweb2-module-doc', 'icingacli' ]:
        ensure  => present,
        require => Apt::Source['icinga-stable-release'],
    }

    file { '/etc/icingaweb2':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'icingaweb2',
        mode    => '2755',
        require => Package['icingaweb2'],
    }

    file { '/etc/icingaweb2/authentication.ini':
        ensure => present,
        content => template('icingaweb2/authentication.ini.erb'),
        owner  => 'www-data',
        group  => 'icingaweb2',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/config.ini':
        ensure => present,
        source => 'puppet:///modules/icingaweb2/config.ini',
        owner  => 'www-data',
        group  => 'icingaweb2',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/groups.ini':
        ensure  => present,
        content => template('icingaweb2/groups.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/resources.ini':
        ensure  => present,
        content => template('icingaweb2/resources.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/roles.ini':
        ensure => present,
        content => template('icingaweb2/roles.ini.erb'),
        owner  => 'www-data',
        group  => 'icingaweb2',
    }

    file { '/etc/icingaweb2/enabledModules':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'icingaweb2',
        mode    => '2755',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/enabledModules/doc':
        ensure  => 'link',
        target  => '/usr/share/icingaweb2/modules/doc',
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/enabledModules'],
    }

    file { '/etc/icingaweb2/enabledModules/monitoring':
        ensure  => 'link',
        target  => '/usr/share/icingaweb2/modules/monitoring',
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/enabledModules'],
    }

    file { '/etc/icingaweb2/enabledModules/setup':
        ensure  => 'link',
        target  => '/usr/share/icingaweb2/modules/setup',
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/enabledModules'],
    }

    file { '/etc/icingaweb2/enabledModules/translation':
        ensure  => 'link',
        target  => '/usr/share/icingaweb2/modules/translation',
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/enabledModules'],
    }

    file { '/etc/icingaweb2/modules':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'icingaweb2',
        mode    => '2755',
        require => File['/etc/icingaweb2'],
    }

    file { '/etc/icingaweb2/modules/monitoring':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'icingaweb2',
        mode    => '2755',
        require => File['/etc/icingaweb2/modules'],
    }
    
    file { '/etc/icingaweb2/modules/monitoring/backends.ini':
        ensure  => present,
        content  => template('icingaweb2/backends.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/modules/monitoring'],
    }

    file { '/etc/icingaweb2/modules/monitoring/commandtransports.ini':
        ensure  => present,
        content => template('icingaweb2/commandtransports.ini.erb'),
        owner   => 'www-data',
        group   => 'icingaweb2',
        require => File['/etc/icingaweb2/modules/monitoring'],
    }

    include ssl::wildcard

    nginx::site { 'icinga2':
        ensure => present,
        source => 'puppet:///modules/icingaweb2/icinga2.conf',
    }

    monitoring::services { 'icinga.miraheze.org HTTPS':
        check_command  => 'check_http',
        vars           => {
            http_ssl   => true,
            http_vhost => 'icinga.miraheze.org',
        },
     }
}
