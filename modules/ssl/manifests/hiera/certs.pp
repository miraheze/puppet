# define resource handler, same as current manual cert handler
define ssl::hiera::certs (
    $url,
    $ca,
    $redirect = undef,
    $sslname = undef,
) {
    if $sslname == undef {
        $sslurl = $url
        $identity = 'full'
    } else {
        $sslurl = $sslname
        $identity = 'partial'
    }

    file { "${sslurl}_${identity}":
        path   => "/etc/ssl/certs/${sslurl}.crt",
        ensure => 'present',
        source => "puppet:///modules/ssl/certificates/${sslurl}.crt",
    }

    file { "${sslurl}_private_${identity}":
        path   => "/etc/ssl/private/${sslurl}.key",
        ensure => 'present',
        source => "puppet:///private/ssl/${sslurl}.key",
    }
}
