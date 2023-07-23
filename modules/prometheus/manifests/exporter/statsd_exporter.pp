class prometheus::exporter::statsd_exporter (
    Array[Hash] $mappings      = lookup('prometheus::exporter::statsd_exporter::mappings'),
    String $listen_address     = ':9112',
) {

    file { '/opt/prometheus-statsd-exporter_0.9.0+ds1-1_amd64.deb':
        ensure  => present,
        source  => 'puppet:///modules/prometheus/statsd_exporter/prometheus-statsd-exporter_0.9.0+ds1-1_amd64.deb',
    }

    package { 'prometheus-statsd-exporter':
        ensure      => installed,
        provider    => dpkg,
        source      => '/opt/prometheus-statsd-exporter_0.9.0+ds1-1_amd64.deb',
        require     => File['/opt/prometheus-statsd-exporter_0.9.0+ds1-1_amd64.deb'],
    }

    $basedir = '/etc/prometheus'
    $config = "${basedir}/statsd_exporter.conf"
    $defaults = {
      'timer_type' => 'summary',
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

    file { $basedir:
        ensure => directory,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
    }

    file { $config:
        content => stdlib::to_yaml({'defaults' => $defaults, 'mappings' => $mappings}),
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
            '--web.listen-address=<%= @listen_address %>',
        '"'], ' ')),
        notify  => Service['prometheus-statsd-exporter'],
    }

    service { 'prometheus-statsd-exporter':
        ensure  => running,
    }

    $firewall_rules_str = join(
        query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
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
