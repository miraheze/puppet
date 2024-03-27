# === Class role::prometheus::statsd_exporter
class role::prometheus::statsd_exporter (
    Array[Hash] $mappings      = lookup('role::prometheus::statsd_exporter::mappings', { 'default_value' => [] }),
    Boolean     $enable_relay  = lookup('role::prometheus::statsd_exporter::enable_relay', { 'default_value' => true }),
    String      $relay_address = lookup('statsd', { 'default_value' => '' }),
    Enum['summary', 'histogram'] $timer_type = lookup('role::prometheus::statsd_exporter::timer_type', { 'default_value' => 'summary' }),
    Array[Variant[Integer, Float]] $histogram_buckets = lookup('role::prometheus::statsd_exporter::histogram_buckets', { 'default_value' => [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],}),
) {
    if $enable_relay {
        $relay_addr = $relay_address
    } else {
        $relay_addr = ''
    }

    class { 'prometheus::exporter::statsd_exporter':
        mappings          => $mappings,
        relay_address     => $relay_addr,
        timer_type        => $timer_type,
        histogram_buckets => $histogram_buckets,
    }

    # Don't spam conntrack with localhost statsd clients
    ferm::client { 'statsd-exporter-client':
        proto   => 'udp',
        notrack => true,
        port    => 9125,
        drange  => ['127.0.0.1'],
    }
}
