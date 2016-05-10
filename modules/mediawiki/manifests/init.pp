# class: mediawiki
class mediawiki {
    include mediawiki::favicons
    include mediawiki::cron
    include mediawiki::nginx
    include ssl::hiera

    if hiera(jobrunner) {
        include mediawiki::jobrunner
    }

    file { [ '/srv/mediawiki', '/srv/mediawiki/dblist', '/srv/mediawiki-static', '/var/log/mediawiki' ]:
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

    file { '/etc/ImageMagick-6/policy.xml':
        ensure => present,
        source => 'puppet:///modules/mediawiki/imagemagick/policy.xml',
        require => Package['imagemagick'],
    }

    # these aren't autoloaded by ssl::hiera
    ssl::cert { 'wildcard.miraheze.org': }
    ssl::cert { 'secure.reviwiki.info': }
    ssl::cert { 'allthetropes.org': }

    nginx::conf { 'mediawiki-includes':
        ensure => present,
        source => 'puppet:///modules/mediawiki/nginx/mediawiki-includes.conf',
    }

    nginx::site { 'hhvm-adminserver':
        ensure  => present,
        source  => 'puppet:///modules/mediawiki/nginx/hhvm-adminserver.conf',
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
        require => Package['ocaml'],
    }

    file { '/etc/php5/fpm/php-fpm.conf':
        ensure => 'present',
        mode   => 0755,
        source => 'puppet:///modules/mediawiki/php/php-fpm.conf',
    }

    file { '/etc/php5/fpm/pool.d/www.conf':
        ensure => 'present',
        mode   => 0755,
        source => 'puppet:///modules/mediawiki/php/www.conf',
    }
}
