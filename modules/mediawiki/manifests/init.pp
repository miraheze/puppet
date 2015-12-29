# class: mediawiki
class mediawiki {
    include mediawiki::cron
    include mediawiki::favicons

    file { [ '/srv/mediawiki', '/srv/mediawiki/dblist', '/srv/mediawiki-static', '/var/log/mediawiki' ]:
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0755',
    }

    file { '/etc/nginx/nginx.conf':
        content => template('mediawiki/nginx.conf.erb'),
    }

    file { '/etc/nginx/sites-enabled/default':
        ensure  => absent,
    }

    $packages = [
        'imagemagick',
        'ploticus',
        'ttf-freefont',
        'ffmpeg2theora',
        'oggvideotools',
        'libav-tools',
        'libvips-tools',
    ]

    package { $packages:
        ensure => present,
    }

    package { [ 'mediawiki-math-texvc', 'ocaml' ]:
        ensure => present,
        install_options => ['--no-install-recommends'],
    }
    
    ssl::cert { 'wildcard.miraheze.org': }
    ssl::cert { 'spiral.wiki': }
    ssl::cert { 'anuwiki.com': }
    ssl::cert { 'antiguabarbudacalypso.com': }
    ssl::cert { 'permanentfuturelab.wiki': }
    ssl::cert { 'secure.reviwiki.info': }
    ssl::cert { 'wiki.printmaking.be': }
    ssl::cert { 'private.revi.wiki': }
    ssl::cert { 'allthetropes.org': }
    ssl::cert { 'oneagencydunedin.wiki': }

    nginx::site { 'mediawiki':
        ensure   => present,
        source   => 'puppet:///modules/mediawiki/nginx/mediawiki.conf',
    }

    nginx::conf { 'mediawiki-includes':
        ensure => present,
        source => 'puppet:///modules/mediawiki/nginx/mediawiki-includes.conf',
    }

    git::clone { 'MediaWiki config':
        directory => '/srv/mediawiki/config',
        origin    => 'https://github.com/miraheze/mw-config.git',
        ensure    => 'latest',
        require   => File['/srv/mediawiki'],
    }

    git::clone { 'MediaWiki core':
        directory           => '/srv/mediawiki/w',
        origin              => 'https://github.com/miraheze/mediawiki.git',
        branch              => 'REL1_26',
        ensure              => 'latest',
        timeout             => '550',
        recurse_submodules  => true,
        require             => File['/srv/mediawiki'],
    }

    git::clone { 'MediaWiki vendor':
        directory => '/srv/mediawiki/w/vendor',
        origin    => 'https://github.com/wikimedia/mediawiki-vendor.git',
        branch    => 'REL1_26',
        ensure    => 'latest',  
        require   => Git::Clone['MediaWiki core'],
    }

    file { '/srv/mediawiki/robots.txt':
        ensure  => 'present',
        source  => 'puppet:///modules/mediawiki/robots.txt',
        require => File['/srv/mediawiki'],
    }

    file { '/srv/mediawiki/w/LocalSettings.php':
        ensure  => 'link',
        target  => '/srv/mediawiki/config/LocalSettings.php',
        require => Git::Clone['MediaWiki config'],
    }

    file { '/srv/mediawiki/config/PrivateSettings.php':
        ensure => 'present',
        source => 'puppet:///private/mediawiki/PrivateSettings.php',
    }

    file { '/usr/local/bin/foreachwikiindblist':
        ensure => 'present',
        mode   => 0755,
        source => 'puppet:///modules/mediawiki/bin/foreachwikiindblist',
    }

    logrotate::rotate { 'mediawiki_wikilogs':
        logs => '/var/log/mediawiki/*.log',
    }

    logrotate::rotate { 'mediawiki_debuglogs':
        logs => '/var/log/mediawiki/debuglogs/*.log',
    }
    
    exec { 'Math texvccheck':
        command => '/usr/bin/make --directory=/srv/mediawiki/w/extensions/Math/texvccheck',
        creates => '/srv/mediawiki/w/extensions/Math/texvccheck/texvccheck',
        user    => 'www-data',
        require => Package['ocaml'],
    }
}
