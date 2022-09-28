# defined type: ssl::cert
define ssl::cert (
    VMlib::Ensure $ensure = 'present',
    String $certificate    = $title,
) {
    if defined(Service['nginx']) {
        $restart_nginx = Service['nginx']
    } else {
        $restart_nginx = undef
    }

    if !defined(File["/etc/ssl/localcerts/${certificate}.crt"]) {
        file { "/etc/ssl/localcerts/${certificate}.crt":
            ensure => $ensure,
            source => "puppet:///ssl/certificates/${certificate}.crt",
            notify => $restart_nginx,
        }
    }

    if !defined(File["/etc/ssl/private/${certificate}.key"]) {
        file { "/etc/ssl/private/${certificate}.key":
            ensure    => $ensure,
            source    => "puppet:///ssl-keys/${certificate}.key",
            owner     => 'root',
            group     => 'ssl-cert',
            mode      => '0660',
            show_diff => false,
            notify    => $restart_nginx,
        }
    }
}
