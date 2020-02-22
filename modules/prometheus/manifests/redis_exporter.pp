# = Class: prometheus::redis
#
class prometheus::redis_exporter (
    $redis_password = hiera('passwords::redis::master'),
) {

    file { '/usr/local/bin/redis_exporter':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/redis/redis_exporter',
    }

    file { '/etc/systemd/system/prometheus-redis.service':
        ensure => present,
        source => 'puppet:///modules/prometheus/redis/prometheus-redis.systemd',
        notify => Service['prometheus-redis'],
    }

    exec { 'prometheus-redis reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/default/prometheus-redis':
        ensure => present,
        content => template('prometheus/prometheus-redis-default.erb'),
        notify => Service['prometheus-redis'],
    }

    service { 'prometheus-redis':
        ensure  => 'running',
        enable  => true,
        require => [
            File['/etc/systemd/system/prometheus-redis.service'],
            File['/usr/local/bin/redis_exporter'],
            File['/etc/default/prometheus-redis'],
        ],
        notify => Exec['prometheus-redis reload systemd'],
    }

    ufw::allow { 'prometheus access 9121 on misc2':
        proto => 'tcp',
        port  => 9121,
        from  => '185.52.3.121',
    }

    ufw::allow { 'prometheus access 9121  ipv4':
        proto => 'tcp',
        port  => 9121,
        from  => '51.89.160.138',
    }

    ufw::allow { 'prometheus access 9121  ipv6':
        proto => 'tcp',
        port  => 9121,
        from  => '2001:41d0:800:105a::6',
    }
}
