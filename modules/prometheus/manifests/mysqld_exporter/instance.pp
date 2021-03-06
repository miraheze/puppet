# == Define: prometheus::mysqld_exporter::instance
#
# Prometheus exporter for MySQL server metrics. The exporter is most effective
# when ran alongside the MySQL server to be monitored, connecting via a local
# UNIX socket is supported.
#
# = Parameters
#
# [*single*]
#   Whether the mysql is an instance or single (e.g mysql@c4)
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

define prometheus::mysqld_exporter::instance (
    Stdlib::Unixpath $client_socket   = '/run/mysqld/mysqld.sock',
    String           $listen_address  = ':9104',
) {
    include prometheus::mysqld_exporter::common

    $my_cnf = "/var/lib/prometheus/.my.${title}.cnf"
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

    $firewall = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "Prometheus mysql ${port} ${value['ipaddress']}":
            proto => 'tcp',
            port  => $port,
            from  => $value['ipaddress'],
        }

        ufw::allow { "Prometheus mysql ${port} ${value['ipaddress6']}":
            proto => 'tcp',
            port  => $port,
            from  => $value['ipaddress6'],
        }
    }
}
