# = Class: prometheus::exporter::fpm
#
class prometheus::exporter::fpm {

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

    firewall::service { 'prometheus php-fpm':
        proto  => 'tcp',
        port   => 9253,
        src_sets => ['PROMETHEUS_HOSTS'],
    }
}
