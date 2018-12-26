# MediaWiki packages
class mediawiki::packages {
    $packages = [
        'djvulibre-bin',
        'dvipng',
        'htmldoc',
        'inkscape',
        'ploticus',
        'ttf-freefont',
        'ffmpeg2theora',
        'locales-all',
        'oggvideotools',
        'libav-tools',
        'libvips-tools',
        'lilypond',
        'poppler-utils',
        'python-pip',
        'netpbm',
        'librsvg2-dev',
        'libjpeg-dev',
        'libgif-dev',
        'p7zip-full',
        'xvfb',
        'timidity',
        'librsvg2-bin',
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

    package { [ 'texvc', 'ocaml' ]:
        ensure          => present,
        install_options => ['--no-install-recommends'],
    }
}
