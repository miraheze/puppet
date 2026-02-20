# === Class imagemagick::install
#
# Installs imagemagick and our custom policy
class imagemagick::install {
    stdlib::ensure_packages(['imagemagick', 'webp'])

    if ($facts['os']['distro']['codename'] == 'trixie') {
        $version = '7'
    } else {
        $version = '6'
    }

    file { "/etc/ImageMagick-${version}/policy.xml":
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        source  => 'puppet:///modules/imagemagick/policy.xml',
        require => Package['imagemagick', 'webp'],
    }
}
