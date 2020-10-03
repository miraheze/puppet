#
define syslog_ng::parser (
  $params = []
) {
  $type = 'parser'
  $id = $title
  $order = '40'

  concat::fragment { "syslog_ng::parser ${title}":
    target  => $::syslog_ng::config_file,
    content => generate_statement($id, $type, $params),
    order   => $order
  }
}
