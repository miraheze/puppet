class prometheus::exporter::postfix {

    file { '/opt/prometheus-postfix-exporter_0.2.0-3+b2_amd64.deb':
        ensure => present,
        source => 'puppet:///modules/prometheus/packages/prometheus-postfix-exporter_0.2.0-3+b2_amd64.deb',
    }

    package { 'prometheus-postfix-exporter':
        ensure   => installed,
        provider => dpkg,
        source   => '/opt/prometheus-postfix-exporter_0.2.0-3+b2_amd64.deb',
        require  => File['/opt/prometheus-postfix-exporter_0.2.0-3+b2_amd64.deb'],
    }

    systemd::service { 'prometheus-postfix-exporter':
        ensure  => present,
        content => systemd_template('prometheus-postfix-exporter'),
        restart => true,
        require => [
            Package['prometheus-postfix-exporter'],
        ],
    }

    $firewall_rules_str = join(
        query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'prometheus postfix_exporter':
        proto  => 'tcp',
        port   => '9154',
        srange => "(${firewall_rules_str})",
    }
}
