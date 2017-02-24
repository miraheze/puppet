# define resource handler, same as current manual cert handler
define ssl::hiera::certs (
    $url,
    $ca,
    $redirect = undef,
    $sslname  = undef,
    $restart  = undef,
) {
    if $sslname == undef {
        $sslurl = $url
    } else {
        $sslurl = $sslname
    }

    if defined(Package['nginx'] {
        $restart = 'nginx'
    } else {
        $restart = 'apache2'
    }

    if !defined(File["${sslurl}"]) {
        file { "${sslurl}":
            ensure => present,
            path   => "/etc/ssl/certs/${sslurl}.crt",
            source => "puppet:///modules/ssl/certificates/${sslurl}.crt",
            notify => Exec["${restart}-syntax"],
        }

        file { "${sslurl}_private":
            ensure => present,
            path   => "/etc/ssl/private/${sslurl}.key",
            source => "puppet:///private/ssl/${sslurl}.key",
            notify => Exec["${restart}-syntax"],
        }
    }
}
