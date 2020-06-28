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

    ufw::allow { 'prometheus access 9050 ipv4':
        proto => 'tcp',
        port  => 9050,
        from  => '51.89.160.138',
    }

    ufw::allow { 'prometheus access 9050 ipv6':
        proto => 'tcp',
        port  => 9050,
        from  => '2001:41d0:800:105a::6',
    }
}
