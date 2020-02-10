# == Class: services

class services {
    include nodejs
    
    require_package('make', 'g++')

    file { '/etc/mediawiki':
        ensure => directory,
    }
}
