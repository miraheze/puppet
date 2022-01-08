class mediawiki::shellbox {
    group { 'shellbox':
        ensure => present,
        system => true,
    }

    user { 'shellbox':
        ensure => present,
        gid    => 'shellbox',
        system => true,
        home   => '/nonexistent',
        shell  => '/usr/sbin/nologin',
    }

    php::fpm::pool { 'shellbox':
        user   => 'shellbox',
        group  => 'shellbox',
        config => {
            'listen.owner' => 'www-data',
            'listen.group' => 'www-data',
            'pm' => 'static',
            'pm.max_children' => 1,
        },
    }

    git::clone { 'shellbox':
        ensure    => present,
        directory => '/srv/shellbox',
        origin    => 'https://gerrit.wikimedia.org/r/mediawiki/libs/Shellbox',
        branch    => 'master',
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
    }

    exec { 'shellbox_composer':
        command     => 'composer install --no-dev',
        creates     => '/srv/shellbox/vendor',
        cwd         => '/srv/shellbox',
        path        => '/usr/bin',
        environment => 'HOME=/srv/shellbox',
        user        => 'www-data',
        require     => Git::Clone['shellbox'],
    }

    file { '/srv/shellbox/config':
        ensure  => directory,
        require => Git::Clone['shellbox'],
    }

    file { '/srv/shellbox/config/config.json':
        ensure  => present,
        source  => 'puppet:///modules/mediawiki/shellbox_config.json',
        require => File['/srv/shellbox/config'],
    }
}
