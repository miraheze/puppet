# === Class mediawiki::packages
#
# Packages needed for mediawiki
class mediawiki::packages {
    include imagemagick::install
    include mediawiki::firejail

    stdlib::ensure_packages([
        'djvulibre-bin',
        'dvipng',
        'espeak-ng-espeak',
        'ffmpeg',
        'fluidsynth',
        'fonts-freefont-ttf',
        'ghostscript',
        'htmldoc',
        'inkscape',
        'lame',
        'libgif-dev',
        'libglew-dev',
        'libglu1-mesa-dev',
        'libjpeg-dev',
        'librsvg2-bin',
        'librsvg2-dev',
        'libvips-tools',
        'libxi-dev',
        'locales-all',
        'netpbm',
        'nodejs',
        'oggvideotools',
        'p7zip-full',
        'ploticus',
        'poppler-utils',
        'python3',
        'python3-minimal',
        'python3-pip',
        'python3-requests',
        'python3-swiftclient',
        'python3-venv',
        'rsync',
        'timidity',
        'xvfb',
    ])

    if !lookup(mediawiki::use_shellbox) {
        stdlib::ensure_packages(
            'lilypond',
            { ensure => absent }
        )
    }
}
