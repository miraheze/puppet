# class: mediawiki
class mediawiki {
    include mediawiki::favicons
    include mediawiki::cron
    include mediawiki::nginx
    include mediawiki::php
    include mediawiki::wikistats
    include ssl::hiera

    if hiera(jobrunner) {
        include mediawiki::jobrunner
    }
    if hiera(mwdumps) {
        include mediawiki::dumps
    }

    file { [ '/srv/mediawiki', '/srv/mediawiki/dblist', '/srv/mediawiki/cdb-config', '/var/log/mediawiki' ]:
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0755',
    }

    file { '/etc/nginx/nginx.conf':
        content => template('mediawiki/nginx.conf.erb'),
        require => Package['nginx'],
    }

    file { '/etc/nginx/fastcgi_params':
        ensure  => present,
        source  => 'puppet:///modules/mediawiki/nginx/fastcgi_params',
    }

    file { '/etc/nginx/sites-enabled/default':
        ensure  => absent,
    }

    $packages = [
        'dvipng',
        'imagemagick',
        'ploticus',
        'ttf-freefont',
        'ffmpeg2theora',
        'locales-all',
        'oggvideotools',
        'libav-tools',
        'libvips-tools',
        'poppler-utils',
    ]

    package { $packages:
        ensure => present,
    }

    package { [ 'mediawiki-math-texvc', 'ocaml' ]:
        ensure => present,
        install_options => ['--no-install-recommends'],
    }

    file { '/etc/ImageMagick-6/policy.xml':
        ensure => present,
        source => 'puppet:///modules/mediawiki/imagemagick/policy.xml',
        require => Package['imagemagick'],
    }

    # these aren't autoloaded by ssl::hiera
    ssl::cert { 'wildcard.miraheze.org': }

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
        branch              => 'REL1_28',
        ensure              => 'latest',
        timeout             => '550',
        recurse_submodules  => true,
        require             => File['/srv/mediawiki'],
    }

    # FIXME: Ugly hack, *everything* in /srv/mediawiki/w should be owned by www-data,
    # but recursive chown in git::clone causes puppet to OOM.
    file { '/srv/mediawiki/w/cache':
        ensure  => directory,
        owner   => 'www-data',
        group   => 'www-data',
        require => Git::Clone['MediaWiki core'],
    }

    git::clone { 'MediaWiki vendor':
        directory => '/srv/mediawiki/w/vendor',
        origin    => 'https://github.com/wikimedia/mediawiki-vendor.git',
        branch    => 'REL1_28',
        ensure    => 'latest', 
        require   => Git::Clone['MediaWiki core'],
    }

    # Ensure widgets template directory is read/writeable by webserver if mediawiki is cloned
    file { '/srv/mediawiki/w/extensions/Widgets/compiled_templates':
        ensure  => directory,
        owner   => 'www-data',
        group   => 'www-data',
        mode   => '0755',
        require => Git::Clone['MediaWiki core'],
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
        logs   => '/var/log/mediawiki/*.log',
        rotate => '6',
        delay  => false,
    }

    logrotate::rotate { 'mediawiki_debuglogs':
        logs   => '/var/log/mediawiki/debuglogs/*.log',
        rotate => '6',
        delay  => false,
    }
    
    exec { 'Math texvccheck':
        command => '/usr/bin/make --directory=/srv/mediawiki/w/extensions/Math/texvccheck',
        creates => '/srv/mediawiki/w/extensions/Math/texvccheck/texvccheck',
        require => [ Git::Clone['MediaWiki core'], Package['ocaml'] ],
    }

    exec { 'curl -sS https://getcomposer.org/installer | php && php composer.phar install':
        creates     => '/srv/mediawiki/w/extensions/Wikibase/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Wikibase',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Wikibase',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }
    exec { 'maps_composer':
        command     => 'curl -sS https://getcomposer.org/installer | php && php composer.phar install',
        creates     => '/srv/mediawiki/w/extensions/Maps/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Maps',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Maps',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    icinga::service { 'mediawiki_rendering':
        description   => 'MediaWiki Rendering',
        check_command => 'check_mediawiki!meta.miraheze.org',
    }

    icinga::service { 'php5-fpm':
        description   => 'php5-fpm',
        check_command => 'check_nrpe_1arg!check_php_fpm',
    }
}
