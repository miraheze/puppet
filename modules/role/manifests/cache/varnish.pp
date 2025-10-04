# role: cache::varnish
class role::cache::varnish (
    Hash $backends = lookup('role::cache::haproxy::varnish_backends'),
) {

    class { 'varnish':
        backends  => $backends,
        use_nginx => false,
    }

    class { 'fail2ban':
        ensure => absent,
    }
    include prometheus::exporter::varnishreqs
}
