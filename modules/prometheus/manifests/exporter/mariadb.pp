# == Class: prometheus::exporter::mariadb
#
# Prometheus exporter for MySQL server metrics. The exporter is most effective
# when ran alongside the MySQL server to be monitored, connecting via a local
# UNIX socket is supported.
class prometheus::exporter::mariadb {
    ensure_packages('prometheus-mysqld-exporter')

    file { '/etc/default/prometheus':
        ensure => directory,
        mode   => '0550',
        owner  => 'prometheus',
        group  => 'prometheus'
    }

    systemd::unit { 'prometheus-mysqld-exporter':
        ensure  => present,
        content => systemd_template('prometheus-mysqld-exporter'),
        require => Package['prometheus-mysqld-exporter']
    }

    $common_options = [
        "web.listen-address \":9104\"",
        "config.my-cnf \"/var/lib/prometheus/.my.cnf\"",
        'collect.binlog_size',
        'collect.global_status',
        'collect.global_variables',
        'collect.engine_innodb_status',
        'collect.info_schema.processlist',
        'collect.slave_status',
        'collect.info_schema.clientstats',
        'collect.info_schema.innodb_metrics',
        'collect.info_schema.query_response_time',
        'collect.info_schema.userstats',
        'collect.mysql.user',
        'no-collect.info_schema.tables'
    ]

    $options_str = $common_options.reduce('') |$memo, $value| {
        "${memo} --${value}"
    }.strip

    file { '/etc/default/prometheus-mysqld-exporter':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => "ARGS='${options_str}'",
        notify  => Service['prometheus-mysqld-exporter'],
    }

    $exporter_password = lookup('passwords::db::exporter')

    file { '/var/lib/prometheus/.my.cnf':
        ensure  => present,
        mode    => '0400',
        owner   => 'prometheus',
        group   => 'prometheus',
        content => template('prometheus/mysqld_exporter.cnf.erb'),
        notify  => Service['prometheus-mysqld-exporter'],
    }

    service { 'prometheus-mysqld-exporter':
        ensure  => running,
    }

    $firewall_rules_str = join(
        query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'prometheus mysqld_exporter':
        proto  => 'tcp',
        port   => '9104',
        srange => "(${firewall_rules_str})",
    }
}
