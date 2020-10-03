#
define syslog_ng::options (
  $options = {}
) {
  $order = '10'

  concat::fragment { "syslog_ng::options ${title}":
    target  => $::syslog_ng::config_file,
    content => generate_options($options),
    order   => $order
  }
}
