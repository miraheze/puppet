# define resource handler, same as current manual cert handler
define ssl::hiera::certs (
    String $url,
    # This is not used in this file, but is used in icinga2.
    String $ca,
    String $hsts     = 'weak',
    Optional[String] $redirect = undef,
    Optional[String] $sslname  = undef,
    # Deprecated use additional_domain
    Optional[String] $mobiledomain  = undef,
    # When specifying this config, also specify regex_domain_ats
    # but instead of using *.example... use .*.example...
    Optional[String] $additional_domain  = undef,
    Optional[String] $regex_domain_ats  = undef,
    Optional[Boolean] $disable_event = true,
) {
    if $sslname == undef {
        $sslurl = $url
    } else {
        $sslurl = $sslname
    }

    if defined(Service['nginx']) {
        $restart_service = Service['nginx']
    } elsif defined(Service['trafficserver']) {
        $restart_service = Service['trafficserver']
    } else {
        $restart_service = undef
    }

    if !defined(File[$sslurl]) {
        file { $sslurl:
            ensure => present,
            path   => "/etc/ssl/localcerts/${sslurl}.crt",
            source => "puppet:///ssl/certificates/${sslurl}.crt",
            notify => $restart_service,
        }
    }

    if !defined(File["${sslurl}_private"]) {
        file { "${sslurl}_private":
            ensure => present,
            path   => "/etc/ssl/private/${sslurl}.key",
            source => "puppet:///ssl-keys/${sslurl}.key",
            owner  => 'root',
            group  => 'ssl-cert',
            mode   => '0660',
            notify => $restart_service,
        }
    }
}
