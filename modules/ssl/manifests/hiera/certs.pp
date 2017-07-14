# define resource handler, same as current manual cert handler
define ssl::hiera::certs (
    $url,
    $ca,
    $hsts     = 'weak',
    $redirect = undef,
    $sslname  = undef,
) {
    if $sslname == undef {
        $sslurl = $url
    } else {
        $sslurl = $sslname
    }

    if defined(Package['nginx']) {
        $restart = 'nginx'
    } else {
        $restart = 'apache2'
    }

    if !defined(File[$sslurl]) {
        file { $sslurl:
            ensure => present,
            path   => "/etc/ssl/certs/${sslurl}.crt",
            source => "puppet:///ssl/certificates/${sslurl}.crt",
            notify => Exec["${restart}-syntax"],
        }

        file { "${sslurl}_private":
            ensure => present,
            path   => "/etc/ssl/private/${sslurl}.key",
            source => "puppet:///ssl-keys/${sslurl}.key",
            notify => Exec["${restart}-syntax"],
        }
    }
}
