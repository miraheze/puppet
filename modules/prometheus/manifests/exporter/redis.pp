# = Class: prometheus::exporter::redis
#
class prometheus::exporter::redis (
    String $redis_password = lookup('passwords::redis::master'),
) {

    file { '/etc/redis_exporter':
        ensure => directory,
        mode   => '0755',
        owner  => 'prometheus',
        group  => 'prometheus',
    }

    file { '/etc/redis_exporter/jobQueueCollector.lua':
        ensure  => present,
        mode    => '0555',
        source  => 'puppet:///modules/prometheus/redis/jobQueueCollector.lua',
        notify  => Service['prometheus-redis-exporter'],
        require => File['/etc/redis_exporter'],
    }

    file { '/usr/local/bin/redis_exporter':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/redis/redis_exporter',
        notify => Service['prometheus-redis-exporter'],
    }

    file { '/etc/default/prometheus-redis':
        ensure  => present,
        content => template('prometheus/prometheus-redis-default.erb'),
        notify  => Service['prometheus-redis-exporter'],
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

    $firewall_rules = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'prometheus redis_exporter':
        proto  => 'tcp',
        port   => '9121',
        srange => "(${firewall_rules_str})",
    }
}
