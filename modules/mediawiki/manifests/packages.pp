# MediaWiki packages
class mediawiki::packages {
    $packages = [
        'djvulibre-bin',
        'dvipng',
        'htmldoc',
        'imagemagick',
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
    ]

    package { $packages:
        ensure => present,
    }

    package { [ 'texvc', 'ocaml' ]:
        ensure          => present,
        install_options => ['--no-install-recommends'],
    }
}
