# = Class: prometheus::exporter::varnishreqs
#
# Periodically export varnish reuqests stats via node-exporter textfile collector.

class prometheus::exporter::varnishreqs (
    VMlib::Ensure $ensure = 'present',
) {
    ensure_packages([
        'python3-prometheus-client',
        'python3-requests',
    ])

    file { '/usr/local/bin/varnish-requests-exporter':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/varnish/varnish-requests-exporter',
    }

    # Collect every minute
    cron { 'varnish-requests-exporter':
        ensure  => $ensure,
        user    => 'root',
        command => '/usr/local/bin/varnish-requests-exporter',
    }
}
