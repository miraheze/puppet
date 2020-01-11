# MediaWiki memcached setup
class mediawiki::memcached {
    package { 'memcached':
        ensure  => present,
    }

    file { '/etc/memcached.conf':
        ensure  => present,
        content => template('mediawiki/memcached.conf.erb')
        notify  => Service['memcached'],
        require => Package['memcached'],
    }

    service { 'memcached':
        ensure  => running,
    }
}
