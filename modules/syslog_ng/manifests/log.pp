#
define syslog_ng::log (
  $params = []
) {
  $order = '80'
  concat::fragment { "syslog_ng::log ${title}":
    target  => $::syslog_ng::config_file,
    content => generate_log($params),
    order   => $order
  }
}
