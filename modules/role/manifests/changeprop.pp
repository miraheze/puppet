# === Role changeprop
class role::changeprop {
    include changeprop

    class { 'role::prometheus::statsd_exporter':
        relay_address     => '',
        timer_type        => 'histogram',
        histogram_buckets => lookup('role::prometheus::statsd_exporter::histogram_buckets', { 'default_value' => [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 60] }),
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Mediawiki] or Class[Role::Icinga2]', ['networking'])
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
    ferm::service { 'changeprop':
        proto   => 'tcp',
        port    => '7200',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    $firewall_rules_prometheus_str = join(
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
    ferm::service { 'changeprop-prometheus':
        proto   => 'tcp',
        port    => '9112',
        srange  => "(${firewall_rules_prometheus_str})",
        notrack => true,
    }

    system::role { 'role::changeprop':
        description => 'ChangeProp server',
    }
}
