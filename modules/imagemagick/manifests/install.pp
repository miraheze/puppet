# === Class imagemagick::install
#
# Installs imagemagick and our custom policy
class imagemagick::install {
    ensure_packages(['imagemagick', 'webp'])

    file { '/etc/ImageMagick-6/policy.xml':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        source  => 'puppet:///modules/imagemagick/policy.xml',
        require => Package['imagemagick', 'webp'],
    }
}
