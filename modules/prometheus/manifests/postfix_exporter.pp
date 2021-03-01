class prometheus::postfix_exporter {

    file { '/opt/prometheus-postfix-exporter_0.2.0-3+b2_amd64.deb':
        ensure  => present,
        source  => 'puppet:///modules/prometheus/packages/prometheus-postfix-exporter_0.2.0-3+b2_amd64.deb',
    }

    package { 'prometheus-postfix-exporter':
        ensure      => installed,
        provider    => dpkg,
        source      => '/opt/prometheus-postfix-exporter_0.2.0-3+b2_amd64.deb',
        require     => File['/opt/prometheus-postfix-exporter_0.2.0-3+b2_amd64.deb'],
    }

    systemd::service { 'prometheus-postfix-exporter':
        ensure  => present,
        content => systemd_template('prometheus-postfix-exporter'),
        restart => true,
        require => [
            Package['prometheus-postfix-exporter'],
        ],
    }

    $firewall = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "Prometheus 9154 ${value['ipaddress']}":
            proto => 'tcp',
            port  => 9154,
            from  => $value['ipaddress'],
        }

        ufw::allow { "Prometheus 9154 ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 9154,
            from  => $value['ipaddress6'],
        }
    }
}
