# class: ssl::wildcard
class ssl::wildcard {
    if !defined(File['/etc/ssl/certs/wildcard.miraheze.org.crt']) {
        file { '/etc/ssl/certs/wildcard.miraheze.org.crt':
            ensure => 'present',
            source => 'puppet:///ssl/certificates/wildcard.miraheze.org.crt',
        }

        file { '/etc/ssl/private/wildcard.miraheze.org.key':
            ensure => 'present',
            mode   => '0644',
            source => 'puppet:///ssl-keys/wildcard.miraheze.org.key',
        }
    }
}

