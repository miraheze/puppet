# == Define: gluster::logging
#
# Read log file and sends to centralised logger (e.g reads /var/log/glusterfs/glusterd.log and sends to graylog).
#
# === Parameters
#
# [file_source_options*]
#   Options for the file source for example [ '/var/log/glusterfs/glusterd.log' ].
#   This essentially reads from the log file and sends it to gluster.
#
# [program_name*]
#   This sets the program name. Sometimes the log is parsed wrong and the
#   program name is set wrong. This corrects the issue.
#
define gluster::logging (
  Array  $file_source_options,
  String $program_name,
) {
  syslog_ng::rewrite { 'r_program':
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
        'rewrite' => 'r_program'
      },
      {
        'destination' => 'd_graylog_syslog_tls',
      },
    ],
  }
}
