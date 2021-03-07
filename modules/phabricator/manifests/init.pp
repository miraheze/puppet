# class: phabricator
class phabricator {

    require_package(['python-pygments', 'python3-pygments', 'subversion'])

    ensure_resource_duplicate('class', 'php::php_fpm', {
        'config'  => {
            'display_errors'            => 'Off',
            'error_log'                 => '/var/log/php/php.log',
            'error_reporting'           => 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
            'log_errors'                => 'On',
            'max_execution_time'        => 230,
            'opcache'                   => {
                'enable'                  => 1,
                'interned_strings_buffer' => 40,
                'memory_consumption'      => 256,
                'max_accelerated_files'   => 20000,
                'max_wasted_percentage'   => 10,
                'validate_timestamps'     => 1,
                'revalidate_freq'         => 10,
            },
            'enable_dl'           => 0,
            'post_max_size'       => '10M',
            'register_argc_argv'  => 'Off',
            'request_order'       => 'GP',
            'track_errors'        => 'Off',
            'upload_max_filesize' => '10M',
            'variables_order'     => 'GPCS',
        },
        'fpm_min_child' => 8,
        'version' => lookup('php::php_version', {'default_value' => '7.3'}),
    })

    $password = lookup('passwords::irc::mirahezebots')

    include ssl::wildcard
    ssl::cert { 'miraheze.wiki': }

    nginx::site { 'phab.miraheze.wiki':
        ensure  => present,
        source  => 'puppet:///modules/phabricator/phab.miraheze.wiki.conf',
        monitor => false,
    }

    nginx::site { 'phabricator.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/phabricator/phabricator.miraheze.org.conf',
        monitor => false,
    }

    file { '/srv/phab':
        ensure => directory,
    }

    git::clone { 'arcanist':
        ensure    => present,
        directory => '/srv/phab/arcanist',
        origin    => 'https://github.com/phacility/arcanist.git',
        require   => File['/srv/phab'],
    }

    git::clone { 'phabricator':
        ensure    => present,
        directory => '/srv/phab/phabricator',
        origin    => 'https://github.com/phacility/phabricator.git',
        require   => File['/srv/phab'],
    }

    #exec { "chk_phab_ext_git_exist":
    #    command => 'true',
    #    path    =>  ['/usr/bin', '/usr/sbin', '/bin'],
    #    onlyif  => 'test ! -d /srv/phab/phabricator/src/extensions/.git'
    #}

    #file {'remove_phab_ext_dir_if_no_git':
    #    ensure  => absent,
    #    path    => '/srv/phab/phabricator/src/extensions',
    #    recurse => true,
    #    purge   => true,
    #    force   => true,
    #    require => Exec['chk_phab_ext_git_exist'],
    #}

    git::clone { 'phabricator-extensions':
        ensure    => latest,
        directory => '/srv/phab/phabricator/src/extensions',
        origin    => 'https://github.com/miraheze/phabricator-extensions.git',
        require   => File['/srv/phab'],
    }

    file { '/srv/phab/repos':
        ensure => directory,
        mode   => '0755',
        owner  => 'www-data',
        group  => 'www-data',
    }

    file { '/srv/phab/images':
        ensure => directory,
        mode   => '0755',
        owner  => 'www-data',
        group  => 'www-data',
    }

    $module_path = get_module_path($module_name)
    $phab_yaml = loadyaml("${module_path}/data/config.yaml")
    $phab_private = {
        'mysql.pass' => lookup('passwords::db::phabricator'),
    }

    $phab_setting = {
        # smtp
        'cluster.mailers'      => [
            {
                'key'          => 'miraheze-smtp',
                'type'         => 'smtp',
                'options'      => {
                    'host'     => 'mail.miraheze.org',
                    'port'     => 587,
                    'user'     => 'noreply',
                    'password' => lookup('passwords::mail::noreply'),
                    'protocol' => 'tls',
                },
            },
        ],
    }

    $phab_settings = merge($phab_yaml, $phab_private, $phab_setting)

    file { '/srv/phab/phabricator/conf/local/local.json':
        ensure  => present,
        content => template('phabricator/local.json.erb'),
        notify  => Service['phd'],
        require => Git::Clone['phabricator'],
    }

    systemd::service { 'phd':
        ensure  => present,
        content => systemd_template('phd'),
        restart => true,
        require => File['/srv/phab/phabricator/conf/local/local.json'],
    }

    monitoring::services { 'phab.miraheze.wiki HTTPS':
        check_command => 'check_http',
        vars          => {
            http_expect => 'HTTP/1.1 200',
            http_ssl    => true,
            http_vhost  => 'phab.miraheze.wiki',
            http_uri    => 'https://phab.miraheze.wiki/file/data/b6eckvcmsmmjwe6gb2as/PHID-FILE-c6u44mun2axi3qq63u5t/ManageWiki-GH.png'
        },
     }

    monitoring::services { 'phabricator.miraheze.org HTTPS':
        check_command => 'check_http',
        vars          => {
            http_ssl   => true,
            http_vhost => 'phabricator.miraheze.org',
        },
     }

    monitoring::services { 'phd':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_phd',
        },
    }
}
