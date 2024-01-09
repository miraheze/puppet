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

    $firewall_rules_str = join(
        query_facts("Class[Role::Prometheus]", ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'prometheus openldap_exporter':
        proto  => 'tcp',
        port   => '9142',
        srange => "(${firewall_rules_str})",
    }
}
