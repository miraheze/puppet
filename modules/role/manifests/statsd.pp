# == Role statsd
#
# Provisions a statsd-proxy instance that listens for StatsD metrics
# on UDP port 8125 and forwards to backends on UDP ports 8126+,
# as well as the set of statsite backends that listen on these ports.
#
class role::statsd (
    Stdlib::Host $graphite_host = lookup('graphite_host', {'default_value' => 'graphite.wikitide.net'}),
){

    class { 'statsd_proxy':
        server_port   => 8125,
        backend_ports => range(8126, 8131),
    }

    monitoring::nrpe { 'statsd-proxy process':
        command => '/usr/lib/nagios/plugins/check_procs -c 1: -C statsd-proxy',
        docs    => 'https://meta.miraheze.org/wiki/Tech:Statsd',
    }

    $firewall_srange = join(
        query_facts('Class[Base]', ['networking'])
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

    # load balancer frontend, backend ports 8126-8131 are only accessed from localhost
    ferm::service { 'statsd':
        proto   => 'udp',
        port    => '8125',
        notrack => true,
        srange  => "(${firewall_srange})",
    }

    class { 'statsite': }

    # statsite backends
    statsite::instance { '8126':
        port          => 8126,
        graphite_host => $graphite_host,
        input_counter => "statsd.${facts['networking']['hostname']}-8126.received",
    }
}