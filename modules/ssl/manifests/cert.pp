# defined type: ssl::cert
define ssl::cert (
    VMlib::Ensure $ensure = 'present',
    String $certificate    = $title,
) {
    if !defined(File["/etc/ssl/certs/${certificate}.crt"]) {
        file { "/etc/ssl/localcerts/${certificate}.crt":
            ensure => $ensure,
            source => "puppet:///ssl/certificates/${certificate}.crt",
        }

        file { "/etc/ssl/private/${certificate}.key":
            ensure => $ensure,
            source => "puppet:///ssl-keys/${certificate}.key",
            owner  => 'root',
            group  => 'ssl-cert',
            mode   => '0660',
        }
    }
}
