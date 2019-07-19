# class: ssl::elasticsearch_wildcard.pp
class ssl::elasticsearch_wildcard ( $es_name ) {
    if !defined(File['es_wildcard.miraheze.org']) {
        file { 'es_wildcard.miraheze.org':
            ensure => 'present',
            source => 'puppet:///ssl/certificates/wildcard.miraheze.org.crt',
            path   => "/etc/elasticsearch/${es_name}/ssl/wildcard.miraheze.org.crt",
        }
    }

    if !defined(File['es_wildcard.miraheze.org_private']) {
        file { 'es_wildcard.miraheze.org_private':
            ensure => 'present',
            source => 'puppet:///ssl-keys/wildcard.miraheze.org.key',
            path   => "/etc/elasticsearch/${es_name}/ssl/wildcard.miraheze.org.key",
        }
    }

    if !defined(File['es_GlobalSign.crt']) {
        file { 'es_GlobalSign.crt':
            ensure => 'present',
            source => 'puppet:///ssl/ca/GlobalSign.crt',
            path   => "/etc/elasticsearch/${es_name}/ssl/GlobalSign.crt",
        }
    }
}
