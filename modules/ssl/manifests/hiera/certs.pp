# define resource handler, same as current manual cert handler
define ssl::hiera::certs (
    String $url,
    # This is not used in this file, but is used in icinga2.
    String $ca,
    String $hsts     = 'weak',
    Optional[String] $redirect = undef,
    Optional[Hash] $path_redirects = undef,
    Optional[String] $sslname  = undef,
    Optional[String] $additional_domain  = undef,
    Optional[Boolean] $disable_event = true,
) {

    if !defined(File['/etc/ssl/localcerts']) {
        file { '/etc/ssl/localcerts':
            ensure  => directory,
            owner   => 'root',
            group   => 'ssl-cert',
            mode    => '0775',
            require => Package['ssl-cert'],
        }
    }

    if $sslname == undef {
        $sslurl = $url
    } else {
        $sslurl = $sslname
    }

    if defined(Service['nginx']) {
        $restart_nginx = Service['nginx']
    } else {
        $restart_nginx = undef
    }

    if !defined(File["/etc/ssl/localcerts/${sslurl}.crt"]) {
        file { "/etc/ssl/localcerts/${sslurl}.crt":
            ensure => present,
            source => "puppet:///ssl/certificates/${sslurl}.crt",
            notify => $restart_nginx,
        }
    }

    if !defined(File["/etc/ssl/private/${sslurl}.key"]) {
        file { "/etc/ssl/private/${sslurl}.key":
            ensure    => present,
            source    => "puppet:///ssl-keys/${sslurl}.key",
            owner     => 'root',
            group     => 'ssl-cert',
            mode      => '0660',
            show_diff => false,
            notify    => $restart_nginx,
        }
    }
}
