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

    ufw::allow { 'prometheus access php-fpm for all hosts ipv4':
        proto => 'tcp',
        port  => 9253,
        from  => '51.89.160.138',
    }

    ufw::allow { 'prometheus access php-fpm for all hosts ipv6':
        proto => 'tcp',
        port  => 9253,
        from  => '2001:41d0:800:105a::6',
    }
}
