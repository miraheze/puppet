# SPDX-License-Identifier: Apache-2.0
class swift::expirer (
    $ensure,
    $statsd_host               = undef,
    $statsd_port               = 8125,
    $statsd_metric_prefix      = undef,
    $statsd_sample_rate_factor = '1',
    $swift_main_memcached      = lookup('swift::proxy::swift_main_memcached', {'default_value' => '10.0.17.108'}),
) {

    package { 'swift-object-expirer':
        ensure => $ensure,
    }

    file { '/etc/swift/object-expirer.conf':
        ensure  => $ensure,
        content => epp('swift/object-expirer.conf.epp', { 'statsd_host' => $statsd_host, 'statsd_port' => $statsd_port, 'statsd_metric_prefix' => $statsd_metric_prefix, 'statsd_sample_rate_factor' => $statsd_sample_rate_factor, 'swift_main_memcached' => $swift_main_memcached }),
        owner   => 'swift',
        group   => 'swift',
        mode    => '0440',
        require => Package['swift-object-expirer'],
    }

    service { 'swift-object-expirer':
        ensure => stdlib::ensure($ensure, 'service'),
    }
}
