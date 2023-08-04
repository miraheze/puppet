# == Class: prometheus::exporter::memcached
#
# Prometheus exporter for memcached server metrics.
#
# = Parameters
#
# [*arguments*]
#   Additional command line arguments for prometheus-memcached-exporter.

class prometheus::exporter::memcached (
    $arguments = '',
) {

    file { '/usr/bin/prometheus-memcached-exporter':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/memcached/memcached_exporter',
        notify => Service['prometheus-memcached-exporter'],
    }

    file { '/etc/default/prometheus-memcached-exporter':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => "ARGS=\"${arguments}\"",
        notify  => Service['prometheus-memcached-exporter'],
    }

    systemd::service { 'prometheus-memcached-exporter':
        ensure  => present,
        content => systemd_template('memcached'),
    }

    $firewall_rules_str = join(
        query_facts("networking.domain='${facts['networking']['domain']}' and Class[Role::Prometheus]", ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'prometheus memcached_exporter':
        proto  => 'tcp',
        port   => '9150',
        srange => "(${firewall_rules_str})",
    }
}
