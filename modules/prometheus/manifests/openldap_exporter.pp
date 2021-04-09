class prometheus::openldap_exporter {

    $monitor_pass = lookup('prometheus::openldap_exporter::monitor_pass')

    file { '/opt/prometheus-openldap-exporter_0+git20171128-3_amd64.deb':
        ensure  => present,
        source  => 'puppet:///modules/prometheus/packages/prometheus-openldap-exporter_0+git20171128-3_amd64.deb',
    }

    package { 'prometheus-openldap-exporter':
        ensure      => installed,
        provider    => dpkg,
        source      => '/opt/prometheus-openldap-exporter_0+git20171128-3_amd64.deb',
        require     => File['/opt/prometheus-openldap-exporter_0+git20171128-3_amd64.deb'],
    }

    file { '/etc/prometheus/openldap-exporter.yaml':
        ensure  => present,
        mode    => '0440',
        owner   => 'prometheus',
        group   => 'prometheus',
        content => template('prometheus/openldap.conf.erb'),
        notify  => Service['prometheus-openldap-exporter'],
    }

    service { 'prometheus-openldap-exporter':
        ensure  => running,
        require => File['/etc/prometheus/openldap-exporter.yaml'],
    }

    $firewall = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "Prometheus 9142 ${value['ipaddress']}":
            proto => 'tcp',
            port  => 9142,
            from  => $value['ipaddress'],
        }

        ufw::allow { "Prometheus 9142 ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 9142,
            from  => $value['ipaddress6'],
        }
    }
}
