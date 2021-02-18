# == Class: prometheus::memcached_exporter
#
# Prometheus exporter for memcached server metrics.
#
# = Parameters
#
# [*arguments*]
#   Additional command line arguments for prometheus-memcached-exporter.

class prometheus::memcached_exporter (
    $arguments = '',
) {

    file { '/usr/local/bin/prometheus-memcached-exporter':
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
        ensure   => present,
        content  => systemd_template('memcached'),
    }

    $firewall = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "prometheus 9150 ${value['ipaddress']}":
            proto => 'tcp',
            port  => 9150,
            from  => $value['ipaddress'],
        }

        ufw::allow { "prometheus 9150 ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 9150,
            from  => $value['ipaddress6'],
        }
    }
}
