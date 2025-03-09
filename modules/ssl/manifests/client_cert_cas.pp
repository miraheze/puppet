# define: ssl::client_cert_cas.pp
define ssl::client_cert_cas (
    $ssl_cert_path = '/etc/ssl/localcerts',
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
        $restart_nginx = Service['nginx']
    } else {
        $restart_nginx = undef
    }

    if !defined(File["${ssl_cert_path}/origin-pull-and-internal-ca.crt"]) {
        file { "${ssl_cert_path}/origin-pull-and-internal-ca.crt":
            ensure => 'present',
            source => 'puppet:///ssl/certificates/origin-pull-and-internal-ca.crt',
            notify => $restart_nginx,
        }
    }

    if !defined(File["${ssl_cert_path}/authenticated_origin_pull_ca.crt"]) {
        file { "${ssl_cert_path}/authenticated_origin_pull_ca.crt":
            ensure => 'present',
            source => 'puppet:///ssl/certificates/authenticated_origin_pull_ca.crt',
            notify => $restart_nginx,
        }
    }

    if !defined(File["${ssl_cert_path}/internal-client-certificate-ca.crt"]) {
        file { "${ssl_cert_path}/internal-client-certificate-ca.crt":
            ensure => 'present',
            source => 'puppet:///ssl/certificates/internal-client-certificate-ca.crt',
            notify => $restart_nginx,
        }
    }
}
