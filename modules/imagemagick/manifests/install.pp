# === Class imagemagick::install
#
# Installs imagemagick and our custom policy
class imagemagick::install {
    ensure_packages(['imagemagick', 'webp'])

    # configuration directory changed since ImageMagick 8:6.8.5.6-1
    file { '/etc/ImageMagick-6/policy.xml':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        source  => 'puppet:///modules/imagemagick/policy.xml',
    }
}
