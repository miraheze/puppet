# == Class: lizardfs::web

class lizardfs::web {

    require_package('lizardfs-cgiserv')

    include ssl::wildcard

    nginx::site { 'lizard.miraheze.org':
         ensure  => present,
         source  => 'puppet:///modules/lizardfs/nginx/nginx.conf',
         monitor => false,
    }

    icinga2::custom::services { 'lizard.miraheze.org HTTPS':
         check_command => 'check_http',
         vars          => {
             http_expect => 'HTTP/1.1 401 Unauthorized',
             http_ssl   => true,
             http_vhost => 'lizard.miraheze.org',
         },
    }
}
