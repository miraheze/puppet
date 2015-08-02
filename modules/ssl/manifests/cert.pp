class ssl::cert (
    $ensure         = 'present',
    $certificate    = $title,
) {
    file { "/etc/ssl/certs/${certificate}.crt":
        ensure => $ensure,
        source => "puppet:///modules/ssl/${certificate}.crt",
    }

    file { "/etc/ssl/private/${certificate}.key":
        ensure => $ensure,
        source => "puppet:///private/ssl/${certificate}.key",
    }
}
