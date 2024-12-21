class prometheus::exporter::varnish (
    String $listen_port = '9131',
) {
    stdlib::ensure_packages('prometheus-varnish-exporter')

    systemd::service { 'prometheus-varnish-exporter':
        ensure  => present,
        content => systemd_template('prometheus-varnish-exporter'),
        restart => true,
    }

    $subquery = @("PQL")
    resources { type = 'Class' and title = 'Role::Prometheus' }
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)

    ferm::service { 'prometheus varnish_exporter':
        proto  => 'tcp',
        port   => $listen_port,
        srange => "(${firewall_rules_str})",
    }
}
