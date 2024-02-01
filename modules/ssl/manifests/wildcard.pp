# define: ssl::wildcard
define ssl::wildcard (
    $ssl_cert_path = '/etc/ssl/localcerts',
    $ssl_cert_key_private_path = '/etc/ssl/private',
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

    if !defined(File["${ssl_cert_path}/wildcard.miraheze.org-2020-2.crt"]) {
        file { "${ssl_cert_path}/wildcard.miraheze.org-2020-2.crt":
            ensure => 'present',
            source => 'puppet:///ssl/certificates/wildcard.miraheze.org-2020-2.crt',
            notify => $restart_nginx,
        }
    }

    if !defined(File["${ssl_cert_key_private_path}/wildcard.miraheze.org-2020-2.key"]) {
        file { "${ssl_cert_key_private_path}/wildcard.miraheze.org-2020-2.key":
            ensure    => 'present',
            source    => 'puppet:///ssl-keys/wildcard.miraheze.org-2020-2.key',
            owner     => 'root',
            group     => 'ssl-cert',
            mode      => '0660',
            show_diff => false,
            notify    => $restart_nginx,
        }
    }
}
