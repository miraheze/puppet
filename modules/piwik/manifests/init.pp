# class: piwik
class piwik {
    git::clone { 'piwik':
        directory => '/srv/piwik',
        origin    => 'https://github.com/piwik/piwik.git',
        branch    => 'master', # FIXME: shouldn't clone master
        owner     => 'www-data',
        group     => 'www-data',
    }

    apache::site { 'piwik.miraheze.org':
        ensure => present,
        source => 'puppet:///modules/piwik/apache.conf',
    }

    file { '/srv/piwik/config/config.ini.php':
        ensure  => present,
        source  => 'puppet:///modules/piwik/config.ini.php',
        require => Git::Clone['piwik'],
    }
}
