# SPDX-License-Identifier: Apache-2.0
class swift::stats::dispersion(
    VMlib::Ensure $ensure = present,
    $statsd_host   = 'localhost',
    $statsd_port   = 9125,
    $statsd_prefix = 'swift.dispersion',
) {
    $required_packages = [
        Package['python3-swiftclient'],
        Package['python3-statsd'],
        Package['swift'],
    ]

    file { '/usr/local/bin/swift-dispersion-stats':
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0555',
        source  => 'puppet:///modules/swift/swift-dispersion-stats.py',
        require => $required_packages,
    }

    # XXX swift-dispersion-populate is not ran/initialized
    systemd::timer::job { 'swift_dispersion_stats':
        ensure          => $ensure,
        user            => 'root',
        description     => 'swift dispersion statistics',
        command         => "/usr/local/bin/swift-dispersion-stats --prefix ${statsd_prefix} --statsd-host ${statsd_host} --statsd-port ${statsd_port}",
        interval        => {'start' => 'OnUnitInactiveSec', 'interval' => '15m'},
        logging_enabled => false,
        require         => File['/usr/local/bin/swift-dispersion-stats'],
    }
}
