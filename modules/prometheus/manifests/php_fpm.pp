# = Class: prometheus::php_fpm
#
class prometheus::php_fpm {

    file { '/usr/local/bin/prometheus-phpfpm-exporter':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/php-fpm/phpfpm_exporter',
        notify => Service['prometheus-php-fpm']
    }

    systemd::service { 'prometheus-php-fpm':
        ensure  => present,
        content => systemd_template('prometheus-php-fpm'),
        restart => true,
        require => File['/usr/local/bin/prometheus-phpfpm-exporter'],
    }

    # TODO: Remove once all modules use ferm.
    $firewall_mode = lookup('base::firewall::mode', {'default_value' => 'ufw'})
    $firewall_rules = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    if $firewall_mode == 'ufw' {
        $firewall_rules.each |$key, $value| {
            ufw::allow { "Prometheus php-fpm 9253 ${value['ipaddress']}":
                proto => 'tcp',
                port  => 9253,
                from  => $value['ipaddress'],
            }

            ufw::allow { "Prometheus php-fpm 9253 ${value['ipaddress6']}":
                proto => 'tcp',
                port  => 9253,
                from  => $value['ipaddress6'],
            }
        }
    } else {
        $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
        $firewall_rules_str = join($firewall_rules_mapped, ' ')

        ferm::service { 'prometheus php-fpm':
            proto  => 'tcp',
            port   => '9253',
            srange => '($firewall_rules_str)',
        }
    }
}
