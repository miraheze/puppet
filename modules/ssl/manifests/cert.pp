# defined type: ssl::cert
define ssl::cert (
    VMlib::Ensure $ensure = 'present',
    String $certificate    = $title,
) {
    if defined(Service['nginx']) {
        $restart_service = Service['nginx']
    } elsif defined(Service['trafficserver']) {
        $restart_service = Service['trafficserver']
    } else {
        $restart_service = undef
    }

    if !defined(File["/etc/ssl/localcerts/${certificate}.crt"]) {
        file { "/etc/ssl/localcerts/${certificate}.crt":
            ensure => $ensure,
            source => "puppet:///ssl/certificates/${certificate}.crt",
            notify => $restart_service,
        }
    }

    if !defined(File["/etc/ssl/private/${certificate}.key"]) {
        file { "/etc/ssl/private/${certificate}.key":
            ensure => $ensure,
            source => "puppet:///ssl-keys/${certificate}.key",
            owner  => 'root',
            group  => 'ssl-cert',
            mode   => '0660',
            notify => $restart_service,
        }
    }
}
