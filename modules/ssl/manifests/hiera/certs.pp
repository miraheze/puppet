# define resource handler, same as current manual cert handler
define ssl::hiera::certs (
    String $url,
    # This is not used in this file, but is used in icinga2.
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

    if defined(Service['nginx']) {
        $restart_nginx = Service['nginx']
    } else {
        $restart_nginx = undef,
    }

    if !defined(File[$sslurl]) {
        file { $sslurl:
            ensure => present,
            path   => "/etc/ssl/localcerts/${sslurl}.crt",
            source => "puppet:///ssl/certificates/${sslurl}.crt",
            notify => $restart_nginx,
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
            notify => $restart_nginx,
        }
    }
}
