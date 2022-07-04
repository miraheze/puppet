# = Class: prometheus::exporter::gdnsd
#
# Periodically export gdnsd stats via node-exporter textfile collector.
#
# Why not a gdnsd_exporter?
#
# In WMF's case there aren't a lot of machines with gdnsd deployed as of Dec 2016.
# Also, having an exporter would have the added benefit of being able to
# aggregate stats on other dimensions rather than per-cluster or per-site.
# from https://github.com/wikimedia/puppet/blob/production/modules/prometheus/manifests/node_gdnsd.pp

class prometheus::exporter::gdnsd (
    VMlib::Ensure $ensure = 'present',
    String $outfile = '/var/lib/prometheus/node.d/gdnsd.prom',
) {
    ensure_packages([
        'python3-prometheus-client',
        'python3-requests',
    ])

    file { '/usr/local/bin/prometheus-gdnsd-stats':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/gdnsd/prometheus-gdnsd-stats.py',
    }

    # Collect every minute
    cron { 'prometheus_gdnsd_stats':
        ensure  => $ensure,
        user    => 'root',
        command => "/usr/local/bin/prometheus-gdnsd-stats --outfile ${outfile}",
    }
}
