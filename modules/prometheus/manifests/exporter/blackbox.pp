# Prometheus black box metrics exporter. See also
# https://github.com/prometheus/blackbox_exporter
#
# This does 'active' checks over TCP / UDP / ICMP / HTTP / DNS
# and reports status to the prometheus scraper
# from https://github.com/wikimedia/puppet/blob/b347052863d4d2e87b37d6c2d9f44f833cfd9dc2/modules/prometheus/manifests/blackbox_exporter.pp

class prometheus::exporter::blackbox {
    ensure_packages('prometheus-blackbox-exporter')

    file { '/etc/prometheus/blackbox.yml':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => template('prometheus/blackbox_exporter.yml.erb'),
        notify  => Service['prometheus-blackbox-exporter'],
    }

    service { 'prometheus-blackbox-exporter':
        ensure     => running,
        hasrestart => true,
        provider   => 'systemd',
        require    => Package['prometheus-blackbox-exporter'],
    }
}
