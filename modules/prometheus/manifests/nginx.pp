# = Class: prometheus::nginx
#

class prometheus::nginx {

    file { '/usr/local/bin/nginx-prometheus-exporter':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/nginx/nginx-prometheus-exporter',
        notify => Service['nginx-prometheus-exporter'],
    }

    systemd::service { 'nginx-prometheus-exporter':
        ensure  => present,
        content => systemd_template('nginx-prometheus-exporter'),
        restart => true,
        require => [
            File['/usr/local/bin/nginx-prometheus-exporter'],
        ],
    }

    # TODO: Remove once all modules use ferm.
    $firewall_mode = lookup('base::firewall::mode', {'default_value' => 'ufw'})
    $firewall_rules = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    if $firewall_mode == 'ufw' {
        $firewall_rules.each |$key, $value| {
            ufw::allow { "prometheus 9113 ${value['ipaddress']}":
                proto => 'tcp',
                port  => 9113,
                from  => $value['ipaddress'],
            }

            ufw::allow { "prometheus 9113 ${value['ipaddress6']}":
                proto => 'tcp',
                port  => 9113,
                from  => $value['ipaddress6'],
            }
        }
    } else {
        $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
        $firewall_rules_str = join($firewall_rules_mapped, ' ')

        ferm::service { 'prometheus nginx':
            proto  => 'tcp',
            port   => '9113',
            srange => "(${firewall_rules_str})",
        }
    }
}
