# == Class: lizardfs::web

class lizardfs::web (
    $modules = ['alias', 'rewrite', 'ssl']
) {

    require_package('lizardfs-cgiserv')

    include ssl::wildcard

    httpd::site { 'lizard.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/lizardfs/apache/apache.conf',
        monitor => true,
    }

    httpd::mod { 'lizardfs_apache':
        modules => $modules,
    }
}
