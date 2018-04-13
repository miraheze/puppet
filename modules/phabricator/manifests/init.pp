# class: phabricator
class phabricator(
    # use php7.2 on stretch+
    $modules = ['ssl', 'php5']
) {
    include ::httpd

    if os_version('debian >= stretch') {
        include ::apt

        if !defined(Apt::Source['php72_apt']) {
            apt::source { 'php72_apt':
                comment  => 'PHP 7.2',
                location => 'http://apt.wikimedia.org/wikimedia',
                release  => "${::lsbdistcodename}-wikimedia",
                repos    => 'thirdparty/php72',
                key      => 'DB3DC2BD4CD504EF2D908FC509DBD9F93F6CD44A',
                notify   => Exec['apt_update_php_phabricator'],
            }

            # First installs can trip without this
            exec {'apt_update_php_phabricator':
                command     => '/usr/bin/apt-get update',
                refreshonly => true,
                logoutput   => true,
            }
        }

        $php_version = '7.2'

        $php_packages = [
            'php-apcu',
            'php-mailparse',
            'php7.2-mysql',
            'php7.2-gd',
            'php7.2-dev',
            'php7.2-curl',
            'php7.2-cli',
            'php7.2-json',
            'php7.2-ldap',
            'php7.2-mbstring',
            'libapache2-mod-php7.2',
            'python-pygments',
            'subversion',
        ]
    } else {
        $php_version = '5'

        $php_packages = [
            'php5-apcu',
            'php5-mysql',
            'php5-gd',
            'php5-mailparse',
            'php5-dev',
            'php5-curl',
            'php5-cli',
            'php5-json',
            'php5-ldap',
            'libapache2-mod-php5',
            'python-pygments',
            'subversion',
        ]
    }

    require_package($php_packages)

    require_package(['python-pygments', 'subversion'])

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
