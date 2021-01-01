# MediaWiki packages
class mediawiki::packages {
    $packages = [
        'djvulibre-bin',
        'dvipng',
        'htmldoc',
        'inkscape',
        'fonts-freefont-ttf',
        'ffmpeg',
        'ffmpeg2theora',
        'locales-all',
        'oggvideotools',
        'libvips-tools',
        'poppler-utils',
        'python-pip',
        'netpbm',
        'librsvg2-dev',
        'libjpeg-dev',
        'libgif-dev',
        'p7zip-full',
        'vmtouch',
        'xvfb',
        'timidity',
        'librsvg2-bin',
        'texlive-latex-extra',
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

    file { '/opt/ploticus_2.42-3+b4_amd64.deb':
        ensure  => present,
        source  => 'puppet:///modules/mediawiki/packages/ploticus/ploticus_2.42-3+b4_amd64.deb',
    }

    package { 'ploticus':
        ensure      => installed,
        provider    => dpkg,
        source      => '/opt/ploticus_2.42-3+b4_amd64.deb',
        require     => File['/opt/ploticus_2.42-3+b4_amd64.deb'],
    }

    file { '/opt/texvc_3.0.0+git20160613-1_amd64.deb':
        ensure  => present,
        source  => 'puppet:///modules/mediawiki/packages/texvc/texvc_3.0.0+git20160613-1_amd64.deb',
    }

    package { 'texvc':
        ensure      => installed,
        provider    => dpkg,
        source      => '/opt/texvc_3.0.0+git20160613-1_amd64.deb',
        require     => [
            File['/opt/texvc_3.0.0+git20160613-1_amd64.deb'],
            Package['texlive-latex-extra'],
        ],
    }

    package { [ 'ocaml' ]:
        ensure          => present,
        install_options => ['--no-install-recommends'],
    }
}
