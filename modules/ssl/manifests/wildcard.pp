# class: ssl::wildcard
class ssl::wildcard (
    $ssl_cert_path = '/etc/ssl/certs',
    $ssl_cert_key_private_path = '/etc/ssl/private',
) {
    # Legacy kept for 2020 TLS certificate switchover
    if !defined(File['wildcard.miraheze.org']) {
        file { 'wildcard.miraheze.org':
            ensure => 'absent',
            source => 'puppet:///ssl/certificates/wildcard.miraheze.org.crt',
            path   => "${ssl_cert_path}/wildcard.miraheze.org.crt",
        }
    }

    if !defined(File['wildcard.miraheze.org_private']) {
        file { 'wildcard.miraheze.org_private':
            ensure => 'absent',
            source => 'puppet:///ssl-keys/wildcard.miraheze.org.key',
            path   => "${ssl_cert_key_private_path}/wildcard.miraheze.org.key",
            owner  => 'root',
            group  => 'ssl-cert',
            mode   => '0660',
        }
    }

    # New certificate for 2020 switchover
    if !defined(File['wildcard.miraheze.org-2020']) {
        file { 'wildcard.miraheze.org-2020':
            ensure => 'present',
            source => 'puppet:///ssl/certificates/wildcard.miraheze.org-2020.crt',
            path   => "${ssl_cert_path}/wildcard.miraheze.org-2020.crt",
        }
    }

    if !defined(File['wildcard.miraheze.org-2020_private']) {
        file { 'wildcard.miraheze.org-2020_private':
            ensure => 'present',
            source => 'puppet:///ssl-keys/wildcard.miraheze.org-2020.key',
            path   => "${ssl_cert_key_private_path}/wildcard.miraheze.org-2020.key",
            owner  => 'root',
            group  => 'ssl-cert',
            mode   => '0660',
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

wildcard.miraheze.org-2020-2.crt
}
