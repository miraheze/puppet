# define resource handler, same as current manual cert handler
define ssl::hiera::certs (
    $url,
    $ca,
    $redirect = undef,
    $sslname = undef,
) {
    if $sslname == undef {
        $sslurl = $url
    } else {
        $sslurl = $sslname
    }

    if !defined(File["${sslurl}"]) {
        file { "${sslurl}":
            path   => "/etc/ssl/certs/${sslurl}.crt",
            ensure => 'present',
            source => "puppet:///modules/ssl/certificates/${sslurl}.crt",
        }

        file { "${sslurl}_private":
            path   => "/etc/ssl/private/${sslurl}.key",
            ensure => 'present',
            source => "puppet:///private/ssl/${sslurl}.key",
        }
    }
}
