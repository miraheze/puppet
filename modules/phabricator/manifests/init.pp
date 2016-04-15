class phabricator {
    include ::apache::mod::ssl
    include ::apache::mod::php5

    apache::site { 'phabricator.miraheze.org':
        ensure => present,
        source => 'puppet:///modules/phabricator/apache.conf',
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

    git::clone { 'libphutil':
        ensure    => present,
        directory => '/srv/phab/libphutil',
        origin    => 'https://github.com/phacility/libphutil.git',
        require   => File['/srv/phab'],
    }

    git::clone { 'phabricator':
        ensure    => present,
        directory => '/srv/phab/phabricator',
        origin    => 'https://github.com/phacility/phabricator.git',
        require   => File['/srv/phab'],
    }

    file { '/srv/phab/repos':
        ensure  => directory,
        mode    => 0755,
        owner   => 'www-data',
        group   => 'www-data',
    }

    $module_path = get_module_path($module_name)
    $phab_yaml = loadyaml("${module_path}/data/config.yaml")
    $phab_private = {
        'mysql.pass'              => $private::mariadb::phabricator_password,
        'phpmailer.smtp-password' => hiera('phabricator::noreply_password'),
    }

    $phab_settings = merge($phab_yaml, $phab_private)

    file { '/srv/phab/phabricator/conf/local/local.json
        ensure  => present,
        content => template('phabricator/local.json.erb'),
    }
}
