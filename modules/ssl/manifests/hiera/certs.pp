# define resource handler, same as current manual cert handler
define ssl::hiera::certs (
    String $url,
    String $ca,
    String $hsts     = 'weak',
    Optional[String] $redirect = undef,
    Optional[String] $sslname  = undef,
    Optional[String] $mobiledomain  = undef,
    Optional[Boolean] $disable_event = true,
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
            path   => "/etc/ssl/localcerts/${sslurl}.crt",
            source => "puppet:///ssl/certificates/${sslurl}.crt",
            notify => Exec["${restart}-syntax"],
        }
    }

    if !defined(File["${sslurl}_private"]) {
        file { "${sslurl}_private":
            ensure => present,
            path   => "/etc/ssl/private/${sslurl}.key",
            source => "puppet:///ssl-keys/${sslurl}.key",
            notify => Exec["${restart}-syntax"],
            owner  => 'root',
            group  => 'ssl-cert',
            mode   => '0660',
        }
    }
}
