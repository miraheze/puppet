class prometheus::openldap_exporter {

    $monitor_pass = lookup('prometheus::openldap_exporter::monitor_pass')

    file { '/usr/loca/bin/prometheus-openldap-exporter':
        ensure  => present,
        source  => 'puppet:///modules/prometheus/openldap/openldap_exporter-linux',
    }

    file { '/etc/openldap-exporter.yaml':
        ensure  => present,
        mode    => '0440',
        owner   => 'prometheus',
        group   => 'prometheus',
        content => template('prometheus/openldap.conf.erb'),
        require => File['/usr/loca/bin/prometheus-openldap-exporter'],
        notify  => Service['prometheus-openldap-exporter'],
    }

    systemd::service { 'prometheus-openldap-exporter':
        ensure  => present,
        restart => true,
        content => systemd_template('prometheus-openldap-exporter'),
        service_params => {
            enable  => true,
            require => File['/etc/openldap-exporter.yaml'],
        }
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
