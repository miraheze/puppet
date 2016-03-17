# define resource handler, same as current manual cert handler
define ssl::hiera::certs (
    $url,
) {
    file { "/etc/ssl/certs/${url}.crt":
        ensure => 'present',
        source => "puppet:///modules/ssl/certificates/${url}.crt",
    }

    file { "/etc/ssl/private/${url}.key":
        ensure => 'present',
        source => "puppet:///private/ssl/${url}.key",
    }
}
