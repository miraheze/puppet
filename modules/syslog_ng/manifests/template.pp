#
define syslog_ng::template (
  $params = []
) {
  $type = 'template'
  $id = $title
  $order = '20'

  concat::fragment { "syslog_ng::template ${title}":
    target  => $::syslog_ng::config_file,
    content => generate_statement($id, $type, $params),
    order   => $order
  }
}
