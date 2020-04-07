# = Class: prometheus::mysqld_exporter
#
class prometheus::mysqld_exporter {

    # should use the version from sid
    require_package('prometheus-mysqld-exporter')

    $exporter_password = lookup('passwords::db::exporter')

    file { '/etc/default/prometheus-mysqld-exporter':
        content => template('prometheus/prometheus-mysqld-exporter.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['prometheus-mysqld-exporter'],
    }

    file { '/var/lib/prometheus/.my.cnf':
        content => template('prometheus/my.cnf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['prometheus-mysqld-exporter'],
    }

    service { 'prometheus-mysqld-exporter':
        ensure  => 'running',
        require => [
            File['/etc/default/prometheus-mysqld-exporter'],
            File['/var/lib/prometheus/.my.cnf'],
        ],
    }

    ufw::allow { 'prometheus mysql monitoring':
        proto   => 'tcp',
        port    => '9104',
        from    => '185.52.3.121',
    }

    ufw::allow { 'prometheus mysql monitoring ipv4':
        proto   => 'tcp',
        port    => '9104',
        from    => '51.89.160.138',
    }

    ufw::allow { 'prometheus mysql monitoring ipv6':
        proto   => 'tcp',
        port    => '9104',
        from    => '2001:41d0:800:105a::6',
    }
}
