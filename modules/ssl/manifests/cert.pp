# defined type: ssl::cert
define ssl::cert (
    Stdlib::Ensure $ensure = 'present',
    String $certificate    = $title,
) {
    if !defined(File["/etc/ssl/certs/${certificate}.crt"]) {
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
