#
define syslog_ng::rewrite (
  $params = []
) {
  $type = 'rewrite'
  $id = $title
  $order = '30'

  concat::fragment { "syslog_ng::rewrite ${title}":
    target  => $::syslog_ng::config_file,
    content => generate_statement($id, $type, $params),
    order   => $order
  }
}
