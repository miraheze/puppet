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
            ensure => present,
            path   => "/etc/ssl/certs/${sslurl}.crt",
            source => "puppet:///modules/ssl/certificates/${sslurl}.crt",
        }

        file { "${sslurl}_private":
            ensure => present,
            path   => "/etc/ssl/private/${sslurl}.key",
            source => "puppet:///private/ssl/${sslurl}.key",
        }
    }
}
