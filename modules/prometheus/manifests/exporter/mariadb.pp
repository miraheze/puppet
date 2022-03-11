# == Define: prometheus::exporter::mariadb
#
# Prometheus exporter for MySQL server metrics. The exporter is most effective
# when ran alongside the MySQL server to be monitored, connecting via a local
# UNIX socket is supported.
#
# = Parameters
#
# [*client_socket*]
#   The socket to connect to.
#
# [*client_user*]
#   MySQL user
#
# [*client_password*]
#   MySQL password
#
# [*listen_address*]
#   ip/host and port, colon separated, where the prometheus exporter will listen for
#   http metrics requests. Host can be omitted.

define prometheus::exporter::mariadb (
    Stdlib::Unixpath $client_socket   = '/run/mysqld/mysqld.sock',
    String           $listen_address  = ':9104',
) {
    require_package('prometheus-mysqld-exporter')

    file { '/etc/default/prometheus':
        ensure => directory,
        mode   => '0550',
        owner  => 'prometheus',
        group  => 'prometheus'
    }

    systemd::unit { 'prometheus-mysqld-exporter@':
        ensure  => present,
        content => systemd_template('prometheus-mysqld-exporter@'),
        require => Package['prometheus-mysqld-exporter']
    }

    $my_cnf = "/var/lib/prometheus/.my.cnf"
    $service = "prometheus-mysqld-exporter@${title}"
    $common_options = [
        "web.listen-address \"${listen_address}\"",
        "config.my-cnf \"${my_cnf}\"",
        'collect.binlog_size',
        'collect.global_status',
        'collect.global_variables',
        'collect.engine_innodb_status',
        'collect.info_schema.processlist',
        'collect.slave_status',
        'no-collect.info_schema.tables'
    ]

    $options_str = $common_options.reduce('') |$memo, $value| {
        "${memo} --${value}"
    }.strip

    file { "/etc/default/prometheus-mysqld-exporter@${title}":
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => "ARGS='${options_str}'",
        notify  => Service[$service],
    }

    $exporter_password = lookup('passwords::db::exporter')

    # a separate database config (.my.<instance_name>cnf) for each instance monitored
    # change the systemd unit if the patch changes here, as it depends on it
    file { $my_cnf:
        ensure  => present,
        mode    => '0400',
        owner   => 'prometheus',
        group   => 'prometheus',
        content => template('prometheus/mysqld_exporter.cnf.erb'),
        notify  => Service[$service],
    }

    service { $service:
        ensure  => running,
        require => File['/lib/systemd/system/prometheus-mysqld-exporter@.service'],
    }

    $port = regsubst($listen_address, ':', '')

    $firewall_rules = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'prometheus mysqld_exporter':
        proto  => 'tcp',
        port   => $port,
        srange => "(${firewall_rules_str})",
    }
}
