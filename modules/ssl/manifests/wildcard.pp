# class: ssl::wildcard
class ssl::wildcard {

    if defined(Package['nginx']) {
        $restart = 'nginx'
    } else {
        $restart = 'apache2'
    }

    if !defined(File['wildcard.miraheze.org']) {
        file { 'wildcard.miraheze.org':
            ensure => 'present',
            source => 'puppet:///ssl/certificates/wildcard.miraheze.org.crt',
            path   => '/etc/ssl/certs/wildcard.miraheze.org.crt',
            notify => Exec["${restart}-syntax"],
        }
    }

    if !defined(File['wildcard.miraheze.org_private']) {
        file { 'wildcard.miraheze.org_private':
            ensure => 'present',
            source => 'puppet:///ssl-keys/wildcard.miraheze.org.key',
            path   => '/etc/ssl/private/wildcard.miraheze.org.key',
            notify => Exec["${restart}-syntax"],
        }
    }
}

