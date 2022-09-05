# == Define: cloud::logging
#
# Read log file and sends to centralised logger.
#
# === Parameters
#
# [file_source_options*]
#   Options for the file source for example [ '/var/log/pveproxy/access.log' ].
#
# [program_name*]
#   This sets the program name. Sometimes the log is parsed wrong and the
#   program name is set wrong. This corrects the issue.
#
define cloud::logging (
  Array  $file_source_options,
  String $program_name,
) {
  syslog_ng::rewrite { "r_program_${program_name}":
    params => {
      'type'    => 'set',
      'options' => [
        $program_name,
        { 'value' => 'PROGRAM' }
      ],
    },
  }
  -> syslog_ng::source { "s_file_${title}":
    params => {
      'type'    => 'file',
      'options' => $file_source_options,
    },
  }
  -> syslog_ng::log { "s_file_${title} to d_graylog_syslog_tls":
    params => [
      {
        'source' => "s_file_${title}",
      },
      {
        'rewrite' => "r_program_${program_name}"
      },
      {
        'destination' => 'd_graylog_syslog_tls',
      },
    ],
  }
}
