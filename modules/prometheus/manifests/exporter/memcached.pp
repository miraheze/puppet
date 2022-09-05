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

    $firewall_rules = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'prometheus memcached_exporter':
        proto  => 'tcp',
        port   => '9150',
        srange => "(${firewall_rules_str})",
    }
}
