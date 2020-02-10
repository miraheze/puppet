# == Class: services

class services {
    include nodejs
    
    require_package('make')

    file { '/etc/mediawiki':
        ensure => directory,
    }
}
