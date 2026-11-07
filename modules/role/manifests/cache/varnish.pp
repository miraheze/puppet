# role: cache::varnish
class role::cache::varnish (
    Hash $backends = lookup('role::cache::haproxy::varnish_backends'),
    Haproxy::Lbpools $lb_pools = lookup('role::cache::haproxy::lb_pools'),
) {

    class { 'varnish':
        backends => $backends,
        lb_pools => $lb_pools,
    }

    include prometheus::exporter::varnishreqs
}
