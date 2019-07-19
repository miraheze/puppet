# class: ssl::wildcard
class ssl::wildcard (
    $ssl_cert_path => '/certs',
    $ssl_private_path => '/private',
    $ssl_path = '/etc/ssl',
) {

    if !defined(File['wildcard.miraheze.org']) {
        file { 'wildcard.miraheze.org':
            ensure => 'present',
            source => 'puppet:///ssl/certificates/wildcard.miraheze.org.crt',
            path   => "${ssl_path}${ssl_cert_path}/wildcard.miraheze.org.crt",
        }
    }

    if !defined(File['wildcard.miraheze.org_private']) {
        file { 'wildcard.miraheze.org_private':
            ensure => 'present',
            source => 'puppet:///ssl-keys/wildcard.miraheze.org.key',
            path   => "${ssl_path}${ssl_private_path}/wildcard.miraheze.org.key",
        }
    }
}
