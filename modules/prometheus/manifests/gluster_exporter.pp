# = Class: prometheus::gluster_exporter
#

class prometheus::gluster_exporter {

    file { '/etc/gluster-exporter.toml':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => template('prometheus/gluster-exporter.toml.erb'),
        notify  => Service['gluster-exporter'],
    }

    file { '/usr/local/bin/gluster-exporter':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/gluster/gluster-exporter',
    }

    systemd::service { 'gluster-exporter':
        ensure  => present,
        content => systemd_template('gluster-exporter'),
        restart => true,
        require => [
            File['/usr/local/bin/gluster-exporter'],
        ],
    }

    $firewall = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "prometheus 9050 ${value['ipaddress']}":
            proto => 'tcp',
            port  => 9050,
            from  => $value['ipaddress'],
        }

        ufw::allow { "prometheus 9050 ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 9050,
            from  => $value['ipaddress6'],
        }
    }
}
