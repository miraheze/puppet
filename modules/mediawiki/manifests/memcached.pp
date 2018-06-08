# MediaWiki memcached setup
class mediawiki::memcached {
    package { 'memcached':
        ensure  => present,
    }

    file { '/etc/memcached.conf':
        ensure  => present,
        source  => 'puppet:///modules/mediawiki/memcached.conf',
        notify  => Service['memcached'],
        require => Package['memcached'],
    }

    service { 'memcached':
        ensure  => running,
    }
}
