# = Class: prometheus::gluster_exporter
#

class prometheus::exporter::gluster {

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

    $firewall_rules = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'prometheus gluster_exporter':
        proto  => 'tcp',
        port   => '9050',
        srange => "(${firewall_rules_str})",
    }
}
