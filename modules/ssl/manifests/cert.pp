# defined type: ssl::cert
define ssl::cert (
    $ensure         = 'present',
    $certificate    = $title,
) {
    if defined(File["/etc/ssl/certs/${certificate}.crt"]) {
        file { "/etc/ssl/certs/${certificate}.crt":
            ensure => $ensure,
            source => "puppet:///ssl/certificates/${certificate}.crt",
        }

        file { "/etc/ssl/private/${certificate}.key":
            ensure => $ensure,
            source => "puppet:///ssl-keys/${certificate}.key",
        }
    }
}
