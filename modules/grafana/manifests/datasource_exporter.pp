# SPDX-License-Identifier: Apache-2.0
# == Class: grafana::datasource_exporter
#
# Grafana datasource usage exporter

class grafana::datasource_exporter (
    VMlib::Ensure   $ensure           = lookup('grafana::datasource_exporter::grafana_url', {'default_value' => 'present'}),
    Stdlib::HTTPUrl $grafana_url     = lookup('grafana::datasource_exporter::grafana_url', {'default_value' => 'http://localhost:3000'}),
    Stdlib::HTTPUrl $pushgateway_url = lookup('grafana::datasource_exporter::pushgateway_url', {'default_value' => 'http://prometheus-pushgateway.wikitide.net:80'}),
    String          $timer_interval  = lookup('grafana::datasource_exporter::timer_interval', {'default_value' => 'hourly'}),
) {

    file { '/usr/local/bin/grafana-datasource-exporter.py':
        ensure => 'present',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        source => 'puppet:///modules/grafana/grafana-datasource-exporter.py';
    }

    $timer_environment = {  'GRAFANA_URL'     => $grafana_url,
                            'PUSHGATEWAY_URL' => $pushgateway_url }

    systemd::timer::job { 'prometheus-grafana-datasource-exporter':
        ensure        => $ensure,
        description   => 'Send grafana dashboard graphite datasource usage metrics to promethues-pushgaeway',
        user          => 'grafana',
        ignore_errors => true,
        environment   => $timer_environment,
        command       => '/usr/local/bin/grafana-datasource-exporter.py',
        interval      => [ { 'start' => 'OnCalendar', 'interval' => $timer_interval }, ],
    }

}