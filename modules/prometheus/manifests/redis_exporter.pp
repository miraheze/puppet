# = Class: prometheus::redis
#
class prometheus::redis_exporter (
    $redis_password = lookup('passwords::redis::master'),
) {

    file { '/usr/local/bin/redis_exporter':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/redis/redis_exporter',
        notify => Service['prometheus-redis'],
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

    $firewall = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "Prometheus  9121 ${value['ipaddress']}":
            proto => 'tcp',
            port  => 9121,
            from  => $value['ipaddress'],
        }

        ufw::allow { "Prometheus 9121 ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 9121,
            from  => $value['ipaddress6'],
        }
    }
}
