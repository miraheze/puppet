# class: phabricator
class phabricator(
    # use php7.2 on stretch+
    $modules = ['ssl', 'php5']
) {
    include ::httpd

    include ::php

    if os_version('debian >= stretch') {
        $php_version = '7.2'
    } else {
        $php_version = '5'
    }

    require_package(["libapache2-mod-php${php_version}", 'python-pygments', 'subversion'])

    $password = hiera('passwords::irc::mirahezebots')

    ssl::cert { 'phab.miraheze.wiki': }

    httpd::site { 'phab.miraheze.wiki':
        ensure  => present,
        source  => 'puppet:///modules/phabricator/phab.miraheze.wiki.conf',
        monitor => true,
    }

    httpd::site { 'phabricator.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/phabricator/phabricator.miraheze.org.conf',
        monitor => true,
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

    exec { "chk_phab_ext_git_exist":
        command => 'true',
        path    =>  ['/usr/bin', '/usr/sbin', '/bin'],
        onlyif  => 'test -d  /srv/phab/phabricator/src/extensions/.git'
    }

    file {'remove_phab_ext_dir_if_no_git':
        ensure  => absent,
        path    => '/srv/phab/phabricator/src/extensions',
        recurse => true,
        purge   => true,
        force   => true,
        require => Exec['chk_phab_ext_git_exist'],
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

    if os_version('debian >= stretch') {
      file { '/etc/php/7.2/apache2/conf.d/php.ini':
          ensure  => present,
          content => template('phabricator/php72.ini.erb'),
          mode    => '0755',
          notify  => Service['apache2'],
          require => Package['libapache2-mod-php7.2'],
      }
    } else {
        file { '/etc/php5/apache2/php.ini':
            ensure  => present,
            mode    => '0755',
            source  => 'puppet:///modules/phabricator/php.ini',
            require => Package['libapache2-mod-php5'],
        }
    }

    httpd::mod { 'phabricator_apache':
        modules => $modules,
        require => Package["libapache2-mod-php${php_version}"],
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
