# = Class: prometheus::php_fpm
#
class prometheus::php_fpm {

    file { '/usr/local/bin/prometheus-phpfpm-exporter':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/php-fpm/phpfpm_exporter',
    }

    file { '/etc/systemd/system/prometheus-php-fpm.service':
        ensure => present,
        source => 'puppet:///modules/prometheus/php-fpm/prometheus-php-fpm.systemd',
        notify => Service['prometheus-php-fpm'],
    }

    exec { 'prometheus-php-fpm reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    service { 'prometheus-php-fpm':
        ensure  => 'running',
        enable  => true,
        require => [
            File['/etc/systemd/system/prometheus-php-fpm.service'],
            File['/usr/local/bin/prometheus-phpfpm-exporter']
        ],
        notify => Exec['prometheus-php-fpm reload systemd'],
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
