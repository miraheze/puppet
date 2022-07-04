# === Class mediawiki::packages
#
# Packages needed for mediawiki
class mediawiki::packages {
    include imagemagick::install
    include mediawiki::firejail

    ensure_packages([
        'djvulibre-bin',
        'dvipng',
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
        'ploticus',
        'poppler-utils',
        'python3-pip',
        'netpbm',
        'librsvg2-dev',
        'libjpeg-dev',
        'libgif-dev',
        'p7zip-full',
        'xvfb',
        'timidity',
        'librsvg2-bin',
        'python3-minimal',
        'python3-requests',
        'rsync',
    ])

    if !lookup(mediawiki::use_shellbox) {
        ensure_packages(
            'lilypond',
            {
                ensure => absent,
            },
        )
    }
}
