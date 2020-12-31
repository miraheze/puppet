# class: ssl::wildcard
class ssl::wildcard (
    $ssl_cert_path = '/etc/ssl/certs',
    $ssl_cert_key_private_path = '/etc/ssl/private',
) {

    # New certificate for 2020 switchover
    if !defined(File['wildcard.miraheze.org-2020']) {
        file { 'wildcard.miraheze.org-2020':
            ensure => 'absent',
        }
    }

    if !defined(File['wildcard.miraheze.org-2020_private']) {
        file { 'wildcard.miraheze.org-2020_private':
            ensure => 'absent',
        }
    }

    if !defined(File['wildcard.miraheze.org-2020-2']) {
        file { 'wildcard.miraheze.org-2020-2':
            ensure => 'present',
            source => 'puppet:///ssl/certificates/wildcard.miraheze.org-2020-2.crt',
            path   => "${ssl_cert_path}/wildcard.miraheze.org-2020-2.crt",
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
        }
    }
}
