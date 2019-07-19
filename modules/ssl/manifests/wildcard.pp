# class: ssl::wildcard
class ssl::wildcard (
    $ssl_cert_path => '/etc/ssl/certs',
    $ssl_cert_key_private_path => '/etc/ssl/private',
) {

    if !defined(File['wildcard.miraheze.org']) {
        file { 'wildcard.miraheze.org':
            ensure => 'present',
            source => 'puppet:///ssl/certificates/wildcard.miraheze.org.crt',
            path   => "${ssl_cert_path}/wildcard.miraheze.org.crt",
        }
    }

    if !defined(File['wildcard.miraheze.org_private']) {
        file { 'wildcard.miraheze.org_private':
            ensure => 'present',
            source => 'puppet:///ssl-keys/wildcard.miraheze.org.key',
            path   => "${ssl_cert_key_private_path}/wildcard.miraheze.org.key",
        }
    }
}
