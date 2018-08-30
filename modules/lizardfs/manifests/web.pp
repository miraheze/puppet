# == Class: lizardfs::web

class lizardfs::web {

    require_package('lizardfs-cgiserv')

    include ssl::wildcard

    nginx::site { 'lizard.miraheze.org':
         ensure  => present,
         source  => 'puppet:///modules/lizardfs/nginx/nginx.conf',
         monitor => false,
    }

    icinga2::custom::services { 'lizard.miraheze.org HTTP':
        check_command => 'check_http',
        vars         => {
            address  => "lizard.miraheze.org",
            http_ssl => false,
        },
    }

    icinga2::custom::services { 'lizard.miraheze.org HTTPS':
        check_command => 'check_http',
        vars          => {
            address  => "lizard.miraheze.org",
            http_ssl  => true,
        },
    }
}
