# = Class: prometheus::redis
#
class prometheus::redis_exporter (
    String $redis_password = lookup('passwords::redis::master'),
) {

    file { '/usr/local/bin/redis_exporter':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/redis/redis_exporter',
        notify => Service['prometheus-redis'],
    }

    file { '/etc/default/prometheus-redis':
        ensure => present,
        content => template('prometheus/prometheus-redis-default.erb'),
        notify => Service['prometheus-redis'],
    }

    systemd::service { 'prometheus-redis-exporter':
        ensure  => present,
        content => systemd_template('prometheus-redis-exporter'),
        restart => true,
        require => [
            File['/etc/default/prometheus-redis'],
            File['/usr/local/bin/redis_exporter']
        ]
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
