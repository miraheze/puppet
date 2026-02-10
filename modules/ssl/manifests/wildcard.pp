# define: ssl::wildcard
define ssl::wildcard (
    String $ssl_cert_path = '/etc/ssl/localcerts',
    String $ssl_cert_key_private_path = '/etc/ssl/private',
    Optional[String] $notify_service = undef,
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

    if defined(Service['nginx']) {
        $_notify_service = Service['nginx']
    } else {
        $_notify_service = $notify_service ? {
          undef   => undef,
          default => Service[$notify_service],
        }
    }

    if !defined(File["${ssl_cert_path}/mirabeta-origin-cert.crt"]) {
        file { "${ssl_cert_path}/mirabeta-origin-cert.crt":
            ensure => 'present',
            source => 'puppet:///ssl/certificates/mirabeta-origin-cert.crt',
            notify => $_notify_service,
        }
    }

    if !defined(File["${ssl_cert_path}/miraheze-origin-cert.crt"]) {
        file { "${ssl_cert_path}/miraheze-origin-cert.crt":
            ensure => 'present',
            source => 'puppet:///ssl/certificates/miraheze-origin-cert.crt',
            notify => $_notify_service,
        }
    }

    if !defined(File["${ssl_cert_path}/wikitide.net.crt"]) {
        file { "${ssl_cert_path}/wikitide.net.crt":
            ensure => 'present',
            source => 'puppet:///ssl/certificates/wikitide.net.crt',
            notify => $_notify_service,
        }
    }

    if !defined(File["${ssl_cert_key_private_path}/wikitide.net.key"]) {
        file { "${ssl_cert_key_private_path}/wikitide.net.key":
            ensure    => 'present',
            source    => 'puppet:///ssl-keys/wikitide.net.key',
            owner     => 'root',
            group     => 'ssl-cert',
            mode      => '0660',
            show_diff => false,
            notify    => $_notify_service,
        }
    }

    if !defined(File["${ssl_cert_key_private_path}/miraheze-origin-cert.key"]) {
        file { "${ssl_cert_key_private_path}/miraheze-origin-cert.key":
            ensure => 'present',
            source => 'puppet:///ssl-keys/miraheze-origin-cert.key',
            notify => $_notify_service,
        }
    }

    if !defined(File["${ssl_cert_key_private_path}/mirabeta-origin-cert.key"]) {
        file { "${ssl_cert_key_private_path}/mirabeta-origin-cert.key":
            ensure => 'present',
            source => 'puppet:///ssl-keys/mirabeta-origin-cert.key',
            notify => $_notify_service,
        }
    }
}
