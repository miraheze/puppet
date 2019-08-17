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

    ufw::allow { 'cp2 433':
        proto => 'tcp',
        port  => 443,
        from  => '107.191.126.23',
    }

    ufw::allow { 'cp3 443':
        proto => 'tcp',
        port  => 443,
        from  => '128.199.139.216',
    }

    ufw::allow { 'cp4 433':
        proto => 'tcp',
        port  => 443,
        from  => '81.4.109.133',
    }

    ufw::allow { 'misc1 433':
        proto => 'tcp',
        port  => 443,
        from  => '185.52.1.76',
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
