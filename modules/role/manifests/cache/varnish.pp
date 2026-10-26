# role: cache::varnish
class role::cache::varnish (
    Hash $backends = lookup('role::cache::haproxy::varnish_backends'),
    Haproxy::Lbpools $mediawiki_lb_pools = lookup('role::cache::haproxy::mediawiki_lb_pools'),
) {

    class { 'varnish':
        backends           => $backends,
        mediawiki_lb_pools => $mediawiki_lb_pools,
    }

    include prometheus::exporter::varnishreqs
}
