# = Class: prometheus::mysqld_exporter
#
class prometheus::mysqld_exporter {

    require_package('prometheus-mysqld-exporter')

    file { '/etc/systemd/system/ prometheus-mysqld-exporter':
        ensure => present,
        source => 'puppet:///modules/prometheus/prometheus-php-fpm.systemd',
        notify => Exec['prometheus-php-fpm reload systemd'],
    }

    file { '/etc/default/prometheus-mysqld-exporter':
        content => template('prometheus/prometheus-mysqld-exporter.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['prometheus'],
    }

    service { ' prometheus-mysqld-exporter':
        ensure  => 'running',
        require => [
            File['/etc/default/prometheus-mysqld-exporter'],
        ],
    }

    ufw::allow { 'prometheus mysql monitoring':
        proto   => 'tcp',
        port    => '9104',
        from    => '81.4.127.174',
    }
}
