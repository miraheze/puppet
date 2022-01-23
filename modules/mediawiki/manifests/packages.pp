# MediaWiki packages
class mediawiki::packages {
    $packages = [
        'djvulibre-bin',
        'dvipng',
        'firejail',
        'ghostscript',
        'htmldoc',
        'inkscape',
        'fonts-freefont-ttf',
        'ffmpeg',
        'locales-all',
        'oggvideotools',
        'libxi-dev',
        'libglu1-mesa-dev',
        'libglew-dev',
        'libvips-tools',
        'lilypond',
        'ploticus',
        'poppler-utils',
#       'python-pip', # Temporarily remove, not compatible with Debian 11
        'netpbm',
        'librsvg2-dev',
        'libjpeg-dev',
        'libgif-dev',
        'p7zip-full',
        'vmtouch',
        'xvfb',
        'timidity',
        'librsvg2-bin',
        'python3-minimal',
        'python3-requests',
        'rsync',
    ]

    # First installs can trip without this
    exec {'apt_update_mediawiki_packages':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
    }

    package { $packages:
        ensure  => present,
        require => Exec['apt_update_mediawiki_packages'],
    }

    file { '/usr/local/bin/mediawiki-firejail-convert':
        source => 'puppet:///modules/mediawiki/mediawiki-firejail-convert.py',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0555',
    }

    file { '/etc/firejail/mediawiki.local':
        source => 'puppet:///modules/mediawiki/firejail-mediawiki.profile',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0644',
    }

    file { '/etc/firejail/mediawiki-converters.profile':
        source => 'puppet:///modules/mediawiki/mediawiki-converters.profile',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0644',
    }

    file { '/usr/local/bin/mediawiki-firejail-ghostscript':
        source => 'puppet:///modules/mediawiki/mediawiki-firejail-ghostscript.py',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0555',
    }
}
