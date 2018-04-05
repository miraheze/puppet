# class: ssl::wildcard
class ssl::wildcard {
    if !defined(File['/etc/ssl/certs/wildcard.miraheze.org.crt']) {
        file { '/etc/ssl/certs/wildcard.miraheze.org.crt':
            ensure => 'present',
            source => 'puppet:///ssl/certificates/wildard.miraheze.org.crt',
        }

        file { '/etc/ssl/private/wildard.miraheze.org.key':
            ensure => 'present',
            source => 'puppet:///ssl-keys/wildard.miraheze.org.key',
        }
    }
}

