# = Class: prometheus::exporter::graylog
#
# Periodically export graylog stats via node-exporter textfile collector.

class prometheus::exporter::graylog (
    VMlib::Ensure $ensure = 'present',
    String $outfile = '/var/lib/prometheus/node.d/graylog.prom',
) {
    # Collect every minute
    systemd::timer::job { 'prometheus_graylog_stats':
        ensure          => $ensure,
        description     => 'Exports graylog metrics',
        command         => "/usr/bin/wget http://127.0.0.1:9833/ -O ${outfile}",
        interval        => {
            start    => 'OnCalendar',
            interval => '*-*-* *:*:00',
        },
        logging_enabled => false,
        user            => 'root',
    }
}
