# MediaWiki services setup
class mediawiki::servicessetup {
    git::clone { 'mathoid':
        ensure    => latest,
        directory => '/srv/mathoid',
        origin    => 'https://github.com/miraheze/mediawiki-mathoid-deploy.git',
        branch    => 'master',
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
        require   => Package['librsvg2-dev'],
    }

    file { '/etc/mathoid':
        ensure  => directory,
    }

    file { '/etc/mathoid/config.yaml':
        ensure  => present,
        source  => 'puppet:///modules/mediawiki/config.yaml',
        require => File['/etc/mathoid'],
    }

    git::clone { '3d2png':
        ensure    => latest,
        directory => '/srv/3d2png',
        origin    => 'https://github.com/miraheze/mediawiki-3d2png-deploy.git',
        branch    => 'master',
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
        require   => Package['libjpeg-dev'],
    }
}
