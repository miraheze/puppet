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

    $firewall = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
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
}
