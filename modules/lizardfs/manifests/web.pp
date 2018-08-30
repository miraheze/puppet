# == Class: lizardfs::web

class lizardfs::web {

    require_package('lizardfs-cgiserv')

    include ssl::wildcard

    nginx::site { 'lizard.miraheze.org':
         ensure  => present,
         source  => 'puppet:///modules/lizardfs/nginx/nginx.conf',
         monitor => true,
    }
}
