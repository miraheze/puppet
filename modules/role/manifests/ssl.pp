# role: ssl
class role::ssl {
    include ::ssl


    if !defined(Firewall::Service['http']) {
        firewall::service { 'http':
            proto   => 'tcp',
            port    => 80,
            src_sets  => ['VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
            notrack => true,
        }
    }

    if !defined(Firewall::Service['https']) {
        firewall::service { 'https':
            proto   => 'tcp',
            port    => 443,
            src_sets  => ['VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
            notrack => true,
        }
    }

    @@sshkey { 'github.com':
        ensure       => present,
        type         => 'ecdsa-sha2-nistp256',
        key          => 'AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=',
        host_aliases => [ 'github.com' ],
    }

    system::role { 'ssl':
        description => 'SSL management server',
    }
}
