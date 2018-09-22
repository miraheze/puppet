# class: ssl::wildcard
class ssl::wildcard {
    if !defined(File['wildcard.miraheze.org']) {
        file { 'wildcard.miraheze.org':
            ensure => 'present',
            source => 'puppet:///ssl/certificates/wildcard.miraheze.org.crt',
            path   => '/etc/ssl/certs/wildcard.miraheze.org.crt',
        }

        file { '/etc/ssl/private/wildcard.miraheze.org.key':
            ensure => 'present',
            source => 'puppet:///ssl-keys/wildcard.miraheze.org.key',
        }
    }
}

