class prometheus::exporter::apache {
    stdlib::ensure_packages('prometheus-apache-exporter')

    file { '/etc/default/prometheus-apache-exporter':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => 'ARGS="--scrape_uri http://127.0.0.1/server-status/?auto"',
        notify  => Service['prometheus-apache-exporter'],
    }

    service { 'prometheus-apache-exporter':
        ensure  => running,
        require => Package['prometheus-apache-exporter'],
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Prometheus]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'prometheus apache exporter':
        proto  => 'tcp',
        port   => '9117',
        srange => "(${firewall_rules_str})",
    }
}
