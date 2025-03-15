class prometheus::exporter::statsd_exporter (
    Enum['summary', 'histogram'] $timer_type,
    Array[Variant[Integer, Float]] $histogram_buckets,
    Array[Hash] $mappings = [],
    String $relay_address = '',
    String $listen_address = ':9112',
    String $arguments = '',
) {

    file { '/opt/prometheus-statsd-exporter_0.26.1-1_amd64.deb':
        ensure => present,
        source => 'puppet:///modules/prometheus/statsd_exporter/prometheus-statsd-exporter_0.26.1-1_amd64.deb',
    }

    package { 'prometheus-statsd-exporter':
        ensure   => installed,
        provider => dpkg,
        source   => '/opt/prometheus-statsd-exporter_0.26.1-1_amd64.deb',
        require  => File['/opt/prometheus-statsd-exporter_0.26.1-1_amd64.deb'],
    }

    $basedir = '/etc/prometheus'
    $config = "${basedir}/statsd_exporter.conf"
    if lookup('prometheus::exporter::statsd_exporter::use_defaults', { 'default_value' => true }) {
        $defaults = {
            'timer_type' => $timer_type,
            'buckets'    => $histogram_buckets,
            'quantiles'  => [
                { 'quantile' => 0.99,
                  'error'    => 0.001  },
                { 'quantile' => 0.95,
                  'error'    => 0.001  },
                { 'quantile' => 0.75,
                  'error'    => 0.001  },
                { 'quantile' => 0.50,
                  'error'    => 0.005  },
            ],
        }

        $content = stdlib::to_yaml({ 'defaults' => $defaults, 'mappings' => $mappings })
    } else {
        $content = stdlib::to_yaml({ 'mappings' => $mappings })
    }

    if (!defined(File[$basedir])) {
        file { $basedir:
            ensure => directory,
            mode   => '0555',
            owner  => 'root',
            group  => 'root',
        }
    }

    file { $config:
        content => $content,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
    }

    file { '/etc/default/prometheus-statsd-exporter':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => inline_template(join(['ARGS="',
            '--statsd.mapping-config=<%= @config %>',
            '<% if not @relay_address.empty? %>--statsd.relay-address=<%= @relay_address %><% end %>',
            '--web.listen-address=<%= @listen_address %>',
            '<%= @arguments %>',
        '"'], ' ')),
        notify  => Service['prometheus-statsd-exporter'],
    }

    service { 'prometheus-statsd-exporter':
        ensure => running,
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
    ferm::service { 'prometheus statsd-exporter':
        proto  => 'tcp',
        port   => '9112',
        srange => "(${firewall_rules_str})",
    }
}
