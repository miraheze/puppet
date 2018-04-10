# class: phabricator
class phabricator {
    include ::apache::mod::ssl
    include ::apache::mod::php5

    $password = hiera('passwords::irc::mirahezebots')

    package { 'php5-apcu':
        ensure => present,
    }

    ssl::cert { 'phab.miraheze.wiki': }

    apache::site { 'phab.miraheze.wiki':
        ensure => present,
        source => 'puppet:///modules/phabricator/phab.miraheze.wiki.conf',
    }

    apache::site { 'phabricator.miraheze.org':
        ensure => present,
        source => 'puppet:///modules/phabricator/phabricator.miraheze.org.conf',
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
        'mysql.pass'              => hiera('passwords::db::phabricator'),
        'phpmailer.smtp-password' => hiera('passwords::mail::noreply'),
    }

    $phab_settings = merge($phab_yaml, $phab_private)

    file { '/srv/phab/phabricator/conf/local/local.json':
        ensure  => present,
        content => template('phabricator/local.json.erb'),
    }

    file { '/etc/php5/apache2/php.ini':
        ensure => present,
        mode   => '0755',
        source => 'puppet:///modules/phabricator/php.ini',
    }

    exec { 'PHD reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/phd.service':
        ensure => present,
        source => 'puppet:///modules/phabricator/phd.systemd',
        notify => Exec['PHD reload systemd'],
    }

    service { 'phd':
        ensure  => 'running',
        require => [File['/etc/systemd/system/phd.service'], File['/srv/phab/phabricator/conf/local/local.json']],
    }

    icinga::service { 'phd':
        description   => 'phd',
        check_command => 'check_nrpe_1arg!check_phd',
    }
}
