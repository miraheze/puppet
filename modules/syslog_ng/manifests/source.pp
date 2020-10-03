#
define syslog_ng::source (
  $params = []
) {
  include syslog_ng

  $type = 'source'
  $id = $title
  $order = '60'

  concat::fragment { "syslog_ng::source ${title}":
    target  => $::syslog_ng::config_file,
    content => generate_statement($id, $type, $params),
    order   => $order
  }
}
