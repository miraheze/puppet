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

    exec { 'prometheus-php-fpm reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/prometheus-php-fpm.service':
        ensure => present,
        source => 'puppet:///modules/prometheus/prometheus-php-fpm.systemd',
        notify => Exec['prometheus-php-fpm reload systemd'],
    }

    service { 'prometheus-php-fpm':
        ensure  => 'running',
        require => [
            File['/etc/systemd/system/prometheus-php-fpm.service'],
            File['/usr/local/bin/prometheus-phpfpm-exporter']
        ],
    }
}
