# == Class: services

class services {
    include nodejs

    file { '/etc/mediawiki':
        ensure => directory,
    }
}
