# role: cache::varnish
class role::cache::varnish (
    Hash $backends = lookup('role::cache::haproxy::varnish_backends'),
) {

    class { 'varnish':
        backends  => $backends,
        use_nginx => false,
    }

    include fail2ban
    include prometheus::exporter::varnishreqs
}
