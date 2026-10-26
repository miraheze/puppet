# role: cache::varnish
class role::cache::varnish (
    Hash $backends = lookup('role::cache::haproxy::varnish_backends'),
    Stdlib::Port $mediawiki_lb_port = lookup('role::cache::haproxy::mediawiki_lb_port'),
) {

    class { 'varnish':
        backends          => $backends,
        mediawiki_lb_port => $mediawiki_lb_port,
    }

    include prometheus::exporter::varnishreqs
}
