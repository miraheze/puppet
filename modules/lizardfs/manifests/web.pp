# == Class: lizardfs::web

class lizardfs::web {

    require_package('lizardfs-cgiserv', 'apache2-utils')

    include ssl::wildcard

    nginx::site { 'lizard.miraheze.org':
         ensure  => present,
         source  => 'puppet:///modules/lizardfs/nginx/nginx.conf',
         monitor => false,
    }

    service { 'lizardfs-cgiserv':
        ensure => running,
        enable => true,
    }

    monitoring::services { 'lizard.miraheze.org HTTPS':
        check_command => 'check_http',
        vars          => {
            http_expect => 'HTTP/1.1 401 Unauthorized',
            http_ssl   => true,
            http_vhost => 'lizard.miraheze.org',
        },
    }
}
