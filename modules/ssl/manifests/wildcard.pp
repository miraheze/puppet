# class: ssl::wildcard
class ssl::wildcard (
    $ssl_cert_path = '/etc/ssl/localcerts',
    $ssl_cert_key_private_path = '/etc/ssl/private',
) {

    if defined(Service['nginx']) {
        $restart_nginx = Service['nginx']
    } else {
        $restart_nginx = undef
    }

    if !defined(File['wildcard.miraheze.org-2020-2']) {
        file { 'wildcard.miraheze.org-2020-2':
            ensure => 'present',
            source => 'puppet:///ssl/certificates/wildcard.miraheze.org-2020-2.crt',
            path   => "${ssl_cert_path}/wildcard.miraheze.org-2020-2.crt",
            notify => $restart_nginx,
        }
    }

    if !defined(File['wildcard.miraheze.org-2020-2_private']) {
        file { 'wildcard.miraheze.org-2020-2_private':
            ensure => 'present',
            source => 'puppet:///ssl-keys/wildcard.miraheze.org-2020-2.key',
            path   => "${ssl_cert_key_private_path}/wildcard.miraheze.org-2020-2.key",
            owner  => 'root',
            group  => 'ssl-cert',
            mode   => '0660',
            notify => $restart_nginx,
        }
    }
}
