class prometheus::exporter::postfix {

    ensure_packages(['prometheus-postfix-exporter'])

    systemd::service { 'prometheus-postfix-exporter':
        ensure  => present,
        content => systemd_template('prometheus-postfix-exporter'),
        restart => true,
        require => [
            Package['prometheus-postfix-exporter'],
        ],
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Prometheus]', ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
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
