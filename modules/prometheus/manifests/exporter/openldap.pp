class prometheus::exporter::openldap {
    $monitor_pass = lookup('prometheus::openldap_exporter::monitor_pass')

    file { '/usr/local/bin/prometheus-openldap-exporter':
        ensure => file,
        mode   => '0555',
        source => 'puppet:///modules/prometheus/openldap/openldap_exporter-linux',
        notify => Service['prometheus-openldap-exporter'],
    }

    file { '/etc/openldap-exporter.yaml':
        ensure  => present,
        mode    => '0440',
        owner   => 'prometheus',
        group   => 'prometheus',
        content => template('prometheus/openldap.conf.erb'),
        notify  => Service['prometheus-openldap-exporter'],
        require => File['/usr/local/bin/prometheus-openldap-exporter'],
    }

    systemd::service { 'prometheus-openldap-exporter':
        ensure         => present,
        restart        => true,
        content        => systemd_template('prometheus-openldap-exporter'),
        service_params => {
            enable  => true,
            require => File['/etc/openldap-exporter.yaml'],
        }
    }

    $firewall_rules = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'prometheus openldap_exporter':
        proto  => 'tcp',
        port   => '9142',
        srange => "(${firewall_rules_str})",
    }
}
